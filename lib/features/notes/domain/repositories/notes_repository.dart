import 'package:core/domain.dart';

import '../entities/note.dart';
import '../entities/note_conflict.dart';
import '../entities/sync_overview.dart';

/// Contract for notes storage and synchronisation.
///
/// Implementations must be **offline-first**: every write succeeds locally
/// without a network, and reads always come from the local copy. Syncing
/// happens in the background; [syncNow] only forces it.
abstract interface class NotesRepository {
  /// Live list of non-deleted notes, newest edit first.
  Stream<List<Note>> watchNotes();

  /// Live sync status.
  Stream<SyncOverview> watchSyncOverview();

  /// Live log of automatically resolved conflicts, newest first.
  Stream<List<NoteConflict>> watchConflicts();

  /// Creates a note locally (works offline).
  Future<Resource<Note>> createNote({
    required String title,
    required String body,
  });

  /// Writes only the given fields (works offline). Passing only the changed
  /// fields matters: it lets another device's edit to a different field
  /// survive the merge.
  Future<Resource<Note>> updateNote({
    required String id,
    String? title,
    String? body,
  });

  /// Deletes a note locally (works offline). The delete is synced as a
  /// tombstone.
  Future<Resource<void>> deleteNote(String id);

  /// Runs a sync cycle now if online.
  Future<Resource<SyncOverview>> syncNow();
}
