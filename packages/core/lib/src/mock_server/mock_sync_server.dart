import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import '../storage/key_value_store.dart';
import '../sync/field_conflict.dart';
import '../sync/lww_merger.dart';
import '../sync/remote/sync_remote_gateway.dart';
import '../sync/sync_record.dart';
import '../utils/async_lock.dart';

/// An in-process stand-in for the real sync backend.
///
/// It implements the same algorithm a production server would:
/// 1. **Idempotency**: every push carries an `opId`; a repeated `opId`
///    returns the stored response without applying anything again.
/// 2. **Merge**: the pushed record is merged with the server copy using the
///    shared `LwwMerger` (per-field Last-Writer-Wins by Hybrid Logical Clock).
/// 3. **Conflict detection**: `ConflictDetector` explains which fields clashed
///    and who won, and the explanation is returned to the device.
/// 4. **Versioning**: every effective change gets the next value of one
///    global, monotonically increasing sequence number, which devices use as
///    their delta-pull cursor.
/// 5. **Change notifications**: [changes] simulates a WebSocket or silent push
///    notification so online devices pull promptly.
///
/// State is persisted in a [KeyValueStore] so the demo survives restarts.
/// Network behaviour (latency, offline) is simulated by `MockRemoteGateway`,
/// not here.
class MockSyncServer {
  MockSyncServer({
    required this._storage,
    this.storageKey = 'mock_server.state',
    this._merger = const LwwMerger(),
    this._detector = const ConflictDetector(),
    this.maxRememberedOps = 500,
  });

  final KeyValueStore _storage;
  final LwwMerger _merger;
  final ConflictDetector _detector;

  /// Storage key for the persisted server state.
  final String storageKey;

  /// How many processed `opId`s are remembered for de-duplication.
  final int maxRememberedOps;

  final Map<String, Map<String, SyncRecord>> _collections = {};
  final LinkedHashMap<String, PushResponse> _processedOps = LinkedHashMap();
  int _sequence = 0;
  bool _opened = false;

  final _lock = AsyncLock();
  final _changes = StreamController<(String, ServerChange)>.broadcast();

  /// The current global version.
  int get currentVersion => _sequence;

  /// Change notifications, tagged with the collection name.
  Stream<(String, ServerChange)> get changes => _changes.stream;

  /// Loads persisted state.
  Future<void> open() => _lock.synchronized(() async {
    if (_opened) return;
    _opened = true;
    final raw = await _storage.read(storageKey);
    if (raw == null) return;
    final json = (jsonDecode(raw) as Map).cast<String, Object?>();
    _sequence = (json['sequence'] as num?)?.toInt() ?? 0;
    final collections = (json['collections'] as Map? ?? const {})
        .cast<String, Object?>();
    for (final entry in collections.entries) {
      _collections[entry.key] = {
        for (final r in entry.value! as List)
          (r as Map)['id'] as String: SyncRecord.fromJson(r.cast()),
      };
    }
    for (final op in (json['processedOps'] as List? ?? const [])) {
      final map = (op as Map).cast<String, Object?>();
      _processedOps[map['opId']! as String] = PushResponse.fromJson(
        (map['response']! as Map).cast(),
      );
    }
  });

  /// Seeds [collection] with [records] if it is empty (first launch).
  Future<void> seedIfEmpty(String collection, List<SyncRecord> records) =>
      _lock.synchronized(() async {
        final target = _collections.putIfAbsent(collection, () => {});
        if (target.isNotEmpty) return;
        for (final record in records) {
          target[record.id] = record.copyWith(version: ++_sequence);
        }
        await _persist();
      });

  /// Handles a push. See the class documentation for the algorithm.
  Future<PushResponse> handlePush(String collection, PushRequest request) =>
      _lock.synchronized(() async {
        final replay = _processedOps[request.opId];
        if (replay != null) return replay.asDuplicate();

        final records = _collections.putIfAbsent(collection, () => {});
        final incoming = request.record;
        final existing = records[incoming.id];

        final SyncRecord stored;
        var conflicts = const <FieldConflict>[];
        var changed = true;

        if (existing == null) {
          stored = incoming.copyWith(version: ++_sequence);
        } else {
          final merged = _merger.merge(existing, incoming);
          conflicts = _detector.detect(
            existing: existing,
            incoming: incoming,
            merged: merged,
            dirtyFields: request.dirtyFields,
            baseClocks: request.baseClocks,
            pushingNodeId: request.deviceId,
          );
          changed = merged.copyWith(version: existing.version) != existing;
          stored = changed ? merged.copyWith(version: ++_sequence) : existing;
        }

        records[incoming.id] = stored;
        final response = PushResponse(record: stored, conflicts: conflicts);
        _processedOps[request.opId] = response;
        while (_processedOps.length > maxRememberedOps) {
          _processedOps.remove(_processedOps.keys.first);
        }
        await _persist();
        if (changed) {
          _changes.add((
            collection,
            ServerChange(
              version: stored.version,
              originDeviceId: request.deviceId,
            ),
          ));
        }
        return response;
      });

  /// Handles a delta pull: records with a version greater than [since].
  Future<PullResponse> handlePull(
    String collection, {
    required int since,
    int limit = 100,
  }) => _lock.synchronized(() {
    final changed =
        (_collections[collection]?.values ?? const <SyncRecord>[])
            .where((r) => r.version > since)
            .toList()
          ..sort((a, b) => a.version.compareTo(b.version));
    final page = changed.take(limit).toList();
    return PullResponse(
      records: page,
      cursor: page.isEmpty ? since : page.last.version,
      hasMore: changed.length > page.length,
    );
  });

  /// Snapshot of a collection (for the demo's server inspector).
  List<SyncRecord> snapshot(String collection) =>
      (_collections[collection]?.values.toList() ?? [])
        ..sort((a, b) => b.version.compareTo(a.version));

  /// Emits [snapshot] now and after every change to [collection].
  Stream<List<SyncRecord>> watchCollection(String collection) async* {
    yield snapshot(collection);
    yield* _changes.stream
        .where((event) => event.$1 == collection)
        .map((_) => snapshot(collection));
  }

  /// Wipes all server state (demo reset).
  Future<void> reset() => _lock.synchronized(() async {
    _collections.clear();
    _processedOps.clear();
    _sequence = 0;
    await _storage.delete(storageKey);
  });

  /// Closes the change stream.
  Future<void> dispose() => _changes.close();

  Future<void> _persist() => _storage.write(
    storageKey,
    jsonEncode({
      'sequence': _sequence,
      'collections': {
        for (final c in _collections.entries)
          c.key: [for (final r in c.value.values) r.toJson()],
      },
      'processedOps': [
        for (final op in _processedOps.entries)
          {'opId': op.key, 'response': op.value.toJson()},
      ],
    }),
  );
}
