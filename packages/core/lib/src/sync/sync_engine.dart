import 'dart:async';
import 'dart:math' as math;

import 'package:core/src/clock/hlc.dart';
import 'package:core/src/clock/hlc_clock.dart';
import 'package:core/src/connectivity/connectivity_service.dart';
import 'package:core/src/sync/conflict_log_entry.dart';
import 'package:core/src/sync/field_conflict.dart';
import 'package:core/src/sync/local/sync_local_store.dart';
import 'package:core/src/sync/lww_merger.dart';
import 'package:core/src/sync/outbox_entry.dart';
import 'package:core/src/sync/remote/sync_remote_gateway.dart';
import 'package:core/src/sync/sync_record.dart';
import 'package:core/src/sync/sync_status.dart';
import 'package:core/src/utils/async_lock.dart';
import 'package:uuid/uuid.dart';

/// A record as the device currently sees it, plus whether it has unsynced
/// local changes.
class TrackedRecord {
  const TrackedRecord({required this.record, required this.hasPendingChanges});

  /// The local copy (the single source of truth for the UI, User Interface).
  final SyncRecord record;

  /// `true` while the record has an outbox entry.
  final bool hasPendingChanges;
}

/// Offline-first synchronisation for one collection on one device.
///
/// ## Responsibilities
/// 1. **Local writes** ([write], [delete]): stamp each changed field with a
///    fresh HLC (Hybrid Logical Clock) timestamp, save the record and its
///    outbox entry in one atomic commit, then schedule a sync. Writes never
///    touch the network, so they work identically offline.
/// 2. **Sync cycle** ([syncNow]): *push* every outbox entry, then *pull*
///    every server change since the cursor. Push first, so the server merges
///    our edits before we read its state.
/// 3. **Triggers**: connectivity regained, a server change notification, a
///    local write (debounced), app start, manual "sync now", and retry with
///    exponential backoff after a failure.
/// 4. **Status** ([watchStatus]) and **conflict log** ([watchConflicts]).
///
/// ## Guarantees
/// * Only one cycle runs at a time (single flight). A trigger during a cycle
///   queues exactly one follow-up cycle.
/// * A crash or network drop at any point loses nothing: the outbox entry is
///   removed only after the server's response is applied, and the server
///   de-duplicates retries by `opId` (idempotency key).
/// * Edits made *while* a push is in flight are kept (see
///   [_applyPushResponse]).
class SyncEngine {
  SyncEngine({
    required this.deviceId,
    required this._store,
    required this._remote,
    required this._connectivity,
    required this._clock,
    this._merger = const LwwMerger(),
    this._uuid = const Uuid(),
    this._debounce = const Duration(milliseconds: 300),
    this._initialBackoff = const Duration(seconds: 2),
    this._maxBackoff = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// This device's id. Also the HLC node id, so conflicts can say who wrote
  /// what.
  final String deviceId;

  final SyncLocalStore _store;
  final SyncRemoteGateway _remote;
  final ConnectivityService _connectivity;
  final HlcClock _clock;
  final LwwMerger _merger;
  final Uuid _uuid;
  final Duration _debounce;
  final Duration _initialBackoff;
  final Duration _maxBackoff;
  final DateTime Function() _now;

  /// Guards every read-modify-write of the local store.
  final _lock = AsyncLock();
  final _statusController = StreamController<SyncStatus>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  late SyncStatus _status;
  Future<SyncReport>? _inFlight;
  bool _rerunRequested = false;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  int _failedAttempts = 0;
  bool _started = false;
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Opens the store, wires the triggers and runs a first sync if online.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _store.open();

    // Keep the clock monotonic across restarts.
    for (final record in _store.allRecords()) {
      final last = record.lastModified;
      if (last != null) _clock.seed(last);
    }

    _status = SyncStatus(
      phase: _connectivity.isOnline ? SyncPhase.idle : SyncPhase.offline,
      isOnline: _connectivity.isOnline,
      pendingCount: _store.pendingOutbox().length,
    );

    _subscriptions
      ..add(_connectivity.onStatusChange.listen(_onConnectivityChanged))
      ..add(_remote.serverChanges.listen(_onServerChange))
      ..add(
        _store.changes.listen(
          (_) => _emit(
            _status.copyWith(pendingCount: _store.pendingOutbox().length),
          ),
        ),
      );

    if (_connectivity.isOnline) unawaited(syncNow());
  }

  /// Cancels timers and subscriptions. Waits for a running cycle to finish.
  Future<void> dispose() async {
    _disposed = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    try {
      await _inFlight;
    } catch (_) {
      // The cycle's own error handling already reported it.
    }
    await _statusController.close();
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Current records (tombstones included) with their pending flag.
  List<TrackedRecord> get records => [
    for (final r in _store.allRecords())
      TrackedRecord(
        record: r,
        hasPendingChanges: _store.outboxEntry(r.id) != null,
      ),
  ];

  /// Emits [records] now and after every local or synced change.
  Stream<List<TrackedRecord>> watchRecords() =>
      _startWith(() => records, _store.changes.map((_) => records));

  /// Current engine status.
  SyncStatus get status => _status;

  /// Emits [status] now and on every change.
  Stream<SyncStatus> watchStatus() =>
      _startWith(() => _status, _statusController.stream);

  /// Emits the conflict log (newest first) now and after every change.
  Stream<List<ConflictLogEntry>> watchConflicts() => _startWith(
    _store.conflictLog,
    _store.changes.map((_) => _store.conflictLog()),
  );

  // ---------------------------------------------------------------------------
  // Local writes (work offline)
  // ---------------------------------------------------------------------------

  /// Writes [changes] (field name to new value) to record [id], creating it if
  /// needed. Only the fields in [changes] get a new clock, which is what
  /// lets concurrent edits to *different* fields both survive.
  Future<SyncRecord> write(String id, Map<String, Object?> changes) async {
    if (changes.isEmpty) {
      throw ArgumentError.value(changes, 'changes', 'must not be empty');
    }
    final updated = await _lock.synchronized(() async {
      final stamp = _clock.now();
      final existing = _store.record(id) ?? SyncRecord.empty(id);
      final updated = existing.withChanges(changes, stamp);
      final pending = _store.outboxEntry(id);

      final entry = pending == null
          // First pending change: remember what it is based on.
          ? OutboxEntry(
              recordId: id,
              opId: _uuid.v4(),
              dirtyFields: changes.keys.toSet(),
              baseClocks: Map.of(existing.clocks),
              baseVersion: existing.version,
              revision: 1,
              createdAt: _now(),
            )
          // Coalesce: keep the original base, add the fields, new idempotency
          // key because the payload changed.
          : pending.copyWith(
              opId: _uuid.v4(),
              dirtyFields: {...pending.dirtyFields, ...changes.keys},
              revision: pending.revision + 1,
            );

      await _store.commit(
        SyncLocalBatch()
          ..putRecords[id] = updated
          ..putOutbox[id] = entry,
      );
      return updated;
    });
    _scheduleSync();
    return updated;
  }

  /// Deletes record [id] by writing a timestamped tombstone. The record stays
  /// in storage so the delete can be synced (and can lose to a newer edit
  /// from another device).
  Future<SyncRecord> delete(String id) =>
      write(id, const {SyncRecord.deletedField: true});

  // ---------------------------------------------------------------------------
  // Sync cycle
  // ---------------------------------------------------------------------------

  /// Runs a push-then-pull cycle now. If one is already running, a single
  /// follow-up cycle is queued and the running cycle's future is returned.
  Future<SyncReport> syncNow() {
    if (_disposed) return Future.value(const SyncReport.offline());
    final running = _inFlight;
    if (running != null) {
      _rerunRequested = true;
      return running;
    }
    _debounceTimer?.cancel();
    final cycle = _runUntilSettled();
    _inFlight = cycle;
    cycle.whenComplete(() => _inFlight = null).ignore();
    return cycle;
  }

  Future<SyncReport> _runUntilSettled() async {
    SyncReport report;
    final conflicts = <FieldConflict>[];
    var pushed = 0;
    var pulled = 0;
    do {
      _rerunRequested = false;
      report = await _runCycle();
      pushed += report.pushed;
      pulled += report.pulled;
      conflicts.addAll(report.conflicts);
    } while (_rerunRequested && !_disposed && _connectivity.isOnline);
    if (report.skippedOffline) return report;
    return SyncReport(pushed: pushed, pulled: pulled, conflicts: conflicts);
  }

  Future<SyncReport> _runCycle() async {
    if (!_connectivity.isOnline) {
      _emit(_status.copyWith(phase: SyncPhase.offline, isOnline: false));
      return const SyncReport.offline();
    }
    _emit(_status.copyWith(phase: SyncPhase.syncing, isOnline: true));

    try {
      final conflicts = <FieldConflict>[];
      final pushed = await _pushAll(conflicts);
      final pulled = await _pullAll();

      _failedAttempts = 0;
      _retryTimer?.cancel();
      _emit(
        _status.copyWith(
          phase: SyncPhase.idle,
          isOnline: _connectivity.isOnline,
          lastSyncedAt: _now(),
          clearError: true,
        ),
      );
      return SyncReport(pushed: pushed, pulled: pulled, conflicts: conflicts);
    } on NetworkException catch (e) {
      // Connectivity said "online" but the server was unreachable, or the
      // connection dropped mid-cycle. Nothing is lost; retry later.
      final online = _connectivity.isOnline;
      _emit(
        _status.copyWith(
          phase: online ? SyncPhase.error : SyncPhase.offline,
          isOnline: online,
          lastError: e.message,
        ),
      );
      _scheduleRetry();
      return const SyncReport.offline();
    } catch (e) {
      _emit(_status.copyWith(phase: SyncPhase.error, lastError: '$e'));
      _scheduleRetry();
      rethrow;
    }
  }

  /// Pushes every outbox entry (oldest first). Returns how many were pushed.
  Future<int> _pushAll(List<FieldConflict> conflicts) async {
    var pushed = 0;
    for (final entry in _store.pendingOutbox()) {
      final record = _store.record(entry.recordId);
      if (record == null) {
        await _store.commit(SyncLocalBatch()..removeOutbox.add(entry.recordId));
        continue;
      }
      final PushResponse response;
      try {
        response = await _remote.push(
          PushRequest(
            opId: entry.opId,
            deviceId: deviceId,
            record: record,
            dirtyFields: entry.dirtyFields,
            baseClocks: entry.baseClocks,
            baseVersion: entry.baseVersion,
          ),
        );
      } on NetworkException catch (e) {
        await _lock.synchronized(() async {
          final current = _store.outboxEntry(entry.recordId);
          if (current == null) return;
          await _store.commit(
            SyncLocalBatch()
              ..putOutbox[entry.recordId] = current.copyWith(
                attempts: current.attempts + 1,
                lastError: e.message,
              ),
          );
        });
        rethrow;
      }
      await _lock.synchronized(() => _applyPushResponse(entry, response));
      conflicts.addAll(response.conflicts);
      pushed++;
    }
    return pushed;
  }

  /// Applies the server's merged record locally.
  ///
  /// If the user edited the record again while the push was in flight, the
  /// outbox entry's revision has moved on: we merge (local newer fields win
  /// by clock), keep the entry, and rebase it on the server's clocks so the
  /// next push does not report a false conflict.
  Future<void> _applyPushResponse(
    OutboxEntry pushed,
    PushResponse response,
  ) async {
    final server = response.record;
    final lastServerClock = server.lastModified;
    if (lastServerClock != null) _clock.observe(lastServerClock);

    final local = _store.record(server.id);
    final merged = local == null
        ? server
        : _merger.merge(local, server).copyWith(version: server.version);

    final batch = SyncLocalBatch()..putRecords[server.id] = merged;
    final latest = _store.outboxEntry(server.id);
    if (latest != null && latest.revision == pushed.revision) {
      batch.removeOutbox.add(server.id);
    } else if (latest != null) {
      batch.putOutbox[server.id] = latest.copyWith(
        baseClocks: Map.of(server.clocks),
        baseVersion: server.version,
      );
    }
    if (!response.wasDuplicate) {
      for (final conflict in response.conflicts) {
        batch.appendConflicts.add(
          ConflictLogEntry(
            id: _uuid.v4(),
            conflict: conflict,
            resolvedRecord: merged,
            resolvedAt: _now(),
          ),
        );
      }
    }
    await _store.commit(batch);
  }

  /// Pulls every page of server changes since the cursor.
  Future<int> _pullAll() async {
    var total = 0;
    while (true) {
      final page = await _remote.pull(since: _store.cursor);
      await _lock.synchronized(() async {
        final batch = SyncLocalBatch()..cursor = page.cursor;
        for (final remote in page.records) {
          final lastRemoteClock = remote.lastModified;
          if (lastRemoteClock != null) _clock.observe(lastRemoteClock);
          final local = _store.record(remote.id);
          // Merging (instead of overwriting) keeps any unsynced local edit
          // that is newer than the server's value; its outbox entry stays and
          // is pushed on the next cycle.
          batch.putRecords[remote.id] = local == null
              ? remote
              : _merger.merge(local, remote).copyWith(version: remote.version);
        }
        await _store.commit(batch);
      });
      total += page.records.length;
      if (!page.hasMore) return total;
    }
  }

  // ---------------------------------------------------------------------------
  // Triggers
  // ---------------------------------------------------------------------------

  void _onConnectivityChanged(bool online) {
    _emit(
      _status.copyWith(
        isOnline: online,
        phase: online ? SyncPhase.idle : SyncPhase.offline,
      ),
    );
    if (online) {
      // Back online: reconcile immediately, forget old backoff.
      _failedAttempts = 0;
      _retryTimer?.cancel();
      unawaited(syncNow());
    }
  }

  void _onServerChange(ServerChange change) {
    if (change.originDeviceId == deviceId) return; // our own echo
    if (change.version <= _store.cursor) return; // already have it
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_disposed || !_connectivity.isOnline) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(syncNow()));
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _failedAttempts++;
    final factor = math.pow(2, math.min(_failedAttempts - 1, 10)).toInt();
    final delay = _initialBackoff * factor;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay > _maxBackoff ? _maxBackoff : delay, () {
      if (_connectivity.isOnline) unawaited(syncNow());
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _emit(SyncStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  static Stream<T> _startWith<T>(
    T Function() current,
    Stream<T> updates,
  ) async* {
    yield current();
    yield* updates;
  }

  /// Exposed for tests: the device's current clock.
  Hlc get lastClock => _clock.last;
}
