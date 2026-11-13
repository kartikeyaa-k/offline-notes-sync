import 'package:core/core.dart';

/// The notes feature's only data source: a thin, feature-named facade over
/// the generic offline-first [SyncEngine] from the core package.
///
/// The engine owns the local store (source of truth), the outbox, and
/// push/pull with the backend, so this feature contains no sync logic at all.
/// It only decides *which fields* a note has (see `NoteFields`).
abstract interface class NotesSyncDataSource {
  /// This device's id.
  String get deviceId;

  /// Local records (tombstones included) with their pending flag.
  Stream<List<TrackedRecord>> watchRecords();

  /// Sync engine status.
  Stream<SyncStatus> watchStatus();

  /// Resolved conflicts, newest first.
  Stream<List<ConflictLogEntry>> watchConflicts();

  /// Writes the given fields of a record locally.
  Future<SyncRecord> write(String id, Map<String, Object?> changes);

  /// Writes a tombstone locally.
  Future<SyncRecord> delete(String id);

  /// Runs a sync cycle now.
  Future<SyncReport> syncNow();

  /// Current status (after [syncNow]).
  SyncStatus get status;
}

/// [NotesSyncDataSource] backed by a [SyncEngine] for the `notes` collection.
class NotesSyncDataSourceImpl implements NotesSyncDataSource {
  const NotesSyncDataSourceImpl(this._engine);

  final SyncEngine _engine;

  @override
  String get deviceId => _engine.deviceId;

  @override
  Stream<List<TrackedRecord>> watchRecords() => _engine.watchRecords();

  @override
  Stream<SyncStatus> watchStatus() => _engine.watchStatus();

  @override
  Stream<List<ConflictLogEntry>> watchConflicts() => _engine.watchConflicts();

  @override
  Future<SyncRecord> write(String id, Map<String, Object?> changes) =>
      _engine.write(id, changes);

  @override
  Future<SyncRecord> delete(String id) => _engine.delete(id);

  @override
  Future<SyncReport> syncNow() => _engine.syncNow();

  @override
  SyncStatus get status => _engine.status;
}
