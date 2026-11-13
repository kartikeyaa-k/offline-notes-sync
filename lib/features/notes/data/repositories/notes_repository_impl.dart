import 'package:core/core.dart';
import 'package:offline_items_app/features/notes/data/datasources/notes_sync_data_source.dart';
import 'package:offline_items_app/features/notes/data/models/note_conflict_model.dart';
import 'package:offline_items_app/features/notes/data/models/note_model.dart';
import 'package:offline_items_app/features/notes/data/models/sync_overview_model.dart';
import 'package:offline_items_app/features/notes/domain/entities/note.dart';
import 'package:offline_items_app/features/notes/domain/entities/note_conflict.dart';
import 'package:offline_items_app/features/notes/domain/entities/sync_overview.dart';
import 'package:offline_items_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:uuid/uuid.dart';

/// Offline-first [NotesRepository].
///
/// Every write goes to the local store through the sync engine and returns
/// immediately, online or not; the engine pushes it when it can. Every read
/// is a stream from the local store, so the UI (User Interface) updates both
/// on local edits and when synced changes from another device arrive.
///
/// Errors are converted to `Failure` once, here, by `guardResource`.
class NotesRepositoryImpl implements NotesRepository {
  const NotesRepositoryImpl(this._dataSource, {this._uuid = const Uuid()});

  final NotesSyncDataSource _dataSource;
  final Uuid _uuid;

  @override
  Stream<List<Note>> watchNotes() =>
      _dataSource.watchRecords().map(NoteModel.visibleNotes);

  @override
  Stream<SyncOverview> watchSyncOverview() =>
      _dataSource.watchStatus().map((s) => SyncOverviewModel(s).toEntity());

  @override
  Stream<List<NoteConflict>> watchConflicts() =>
      _dataSource.watchConflicts().map(
        (entries) => [for (final e in entries) NoteConflictModel(e).toEntity()],
      );

  @override
  Future<Resource<Note>> createNote({
    required String title,
    required String body,
  }) => guardResource(() async {
    // The id is generated on the device, so creation never needs the
    // server.
    final record = await _dataSource.write(
      _uuid.v4(),
      NoteModel.changes(title: title, body: body),
    );
    return _toNote(record);
  }, fallbackMessage: 'Could not save the note.');

  @override
  Future<Resource<Note>> updateNote({
    required String id,
    String? title,
    String? body,
  }) => guardResource(() async {
    final record = await _dataSource.write(
      id,
      NoteModel.changes(title: title, body: body),
    );
    return _toNote(record);
  }, fallbackMessage: 'Could not save the note.');

  @override
  Future<Resource<void>> deleteNote(String id) => guardResource(
    () => _dataSource.delete(id),
    fallbackMessage: 'Could not delete the note.',
  );

  @override
  Future<Resource<SyncOverview>> syncNow() => guardResource(() async {
    final report = await _dataSource.syncNow();
    final overview = SyncOverviewModel(_dataSource.status).toEntity();
    if (report.skippedOffline) {
      throw ResourceException(
        overview.isOnline
            ? 'Server unreachable. Changes are saved and will sync automatically.'
            : 'You are offline. Changes are saved and will sync when you reconnect.',
        code: 'offline',
      );
    }
    return overview;
  }, fallbackMessage: 'Sync failed. It will retry automatically.');

  Note _toNote(SyncRecord record) =>
      NoteModel(TrackedRecord(record: record, hasPendingChanges: true))
          .toEntity();
}
