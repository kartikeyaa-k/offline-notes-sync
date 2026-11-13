import 'dart:async';
import 'dart:convert';

import '../../storage/key_value_store.dart';
import '../conflict_log_entry.dart';
import '../outbox_entry.dart';
import '../sync_record.dart';

/// One atomic set of changes to the local store.
///
/// Every local edit writes the record **and** its outbox entry in one batch,
/// so they can never get out of step (for example after a crash).
class SyncLocalBatch {
  /// Records to insert or replace.
  final Map<String, SyncRecord> putRecords = {};

  /// Outbox entries to insert or replace.
  final Map<String, OutboxEntry> putOutbox = {};

  /// Record ids whose outbox entry should be removed.
  final Set<String> removeOutbox = {};

  /// New delta-pull cursor, if it changed.
  int? cursor;

  /// Conflicts to append to the log.
  final List<ConflictLogEntry> appendConflicts = [];

  /// `true` when the batch changes nothing.
  bool get isEmpty =>
      putRecords.isEmpty &&
      putOutbox.isEmpty &&
      removeOutbox.isEmpty &&
      cursor == null &&
      appendConflicts.isEmpty;
}

/// The device's local database for one collection: the **single source of
/// truth** the UI (User Interface) reads from, online or offline.
///
/// It holds:
/// * the records (including tombstones),
/// * the outbox of pending changes,
/// * the delta-pull cursor (last server version seen),
/// * a capped log of resolved conflicts.
///
/// Reads are synchronous from an in-memory cache loaded by [open]; writes go
/// through [commit].
abstract interface class SyncLocalStore {
  /// Loads persisted state. Must be called once before anything else.
  Future<void> open();

  /// A record by id (tombstones included), or `null`.
  SyncRecord? record(String id);

  /// All records (tombstones included).
  List<SyncRecord> allRecords();

  /// The pending outbox entry for [recordId], or `null`.
  OutboxEntry? outboxEntry(String recordId);

  /// All pending outbox entries, oldest first.
  List<OutboxEntry> pendingOutbox();

  /// The last server version pulled.
  int get cursor;

  /// Resolved conflicts, newest first.
  List<ConflictLogEntry> conflictLog();

  /// Applies [batch] atomically and persists it.
  Future<void> commit(SyncLocalBatch batch);

  /// Fires after every commit.
  Stream<void> get changes;

  /// Deletes everything (used by logout and by the demo's reset button).
  Future<void> clear();

  /// Releases resources.
  Future<void> dispose();
}

/// [SyncLocalStore] that keeps the whole collection as one JSON (JavaScript
/// Object Notation) document under a single key of a [KeyValueStore].
///
/// One key means every [commit] is one atomic write. This is ideal for a
/// mini project and a few thousand small items. For large data sets,
/// implement [SyncLocalStore] on SQLite (for example drift) with the same
/// semantics; nothing else changes.
class KeyValueSyncLocalStore implements SyncLocalStore {
  KeyValueSyncLocalStore({
    required this._storage,
    required this.storageKey,
    this.maxConflictLogEntries = 50,
  });

  final KeyValueStore _storage;

  /// The key this collection is stored under, for example
  /// `sync.device-a.notes`.
  final String storageKey;

  /// How many conflict log entries are kept.
  final int maxConflictLogEntries;

  final Map<String, SyncRecord> _records = {};
  final Map<String, OutboxEntry> _outbox = {};
  final List<ConflictLogEntry> _conflicts = [];
  int _cursor = 0;
  final _changes = StreamController<void>.broadcast();

  // Serialises writes so two commits never interleave their persistence.
  Future<void> _writeQueue = Future.value();

  @override
  Future<void> open() async {
    final raw = await _storage.read(storageKey);
    if (raw == null) return;
    final json = (jsonDecode(raw) as Map).cast<String, Object?>();
    for (final r in (json['records'] as List? ?? const [])) {
      final record = SyncRecord.fromJson((r as Map).cast());
      _records[record.id] = record;
    }
    for (final o in (json['outbox'] as List? ?? const [])) {
      final entry = OutboxEntry.fromJson((o as Map).cast());
      _outbox[entry.recordId] = entry;
    }
    for (final c in (json['conflicts'] as List? ?? const [])) {
      _conflicts.add(ConflictLogEntry.fromJson((c as Map).cast()));
    }
    _cursor = (json['cursor'] as num?)?.toInt() ?? 0;
  }

  @override
  SyncRecord? record(String id) => _records[id];

  @override
  List<SyncRecord> allRecords() => List.unmodifiable(_records.values);

  @override
  OutboxEntry? outboxEntry(String recordId) => _outbox[recordId];

  @override
  List<OutboxEntry> pendingOutbox() =>
      _outbox.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  int get cursor => _cursor;

  @override
  List<ConflictLogEntry> conflictLog() => List.unmodifiable(_conflicts);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> commit(SyncLocalBatch batch) {
    if (batch.isEmpty) return Future.value();
    // Apply to memory first, synchronously, so readers see it immediately.
    _records.addAll(batch.putRecords);
    batch.removeOutbox.forEach(_outbox.remove);
    _outbox.addAll(batch.putOutbox);
    if (batch.cursor != null) _cursor = batch.cursor!;
    if (batch.appendConflicts.isNotEmpty) {
      _conflicts.insertAll(0, batch.appendConflicts.reversed);
      if (_conflicts.length > maxConflictLogEntries) {
        _conflicts.removeRange(maxConflictLogEntries, _conflicts.length);
      }
    }
    final snapshot = _encode();
    _writeQueue = _writeQueue.then((_) => _storage.write(storageKey, snapshot));
    return _writeQueue.then((_) {
      if (!_changes.isClosed) _changes.add(null);
    });
  }

  @override
  Future<void> clear() async {
    _records.clear();
    _outbox.clear();
    _conflicts.clear();
    _cursor = 0;
    await (_writeQueue = _writeQueue.then((_) => _storage.delete(storageKey)));
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Future<void> dispose() async {
    await _writeQueue;
    await _changes.close();
  }

  String _encode() => jsonEncode({
    'records': [for (final r in _records.values) r.toJson()],
    'outbox': [for (final o in _outbox.values) o.toJson()],
    'conflicts': [for (final c in _conflicts) c.toJson()],
    'cursor': _cursor,
  });
}
