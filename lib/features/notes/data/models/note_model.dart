import 'package:core/core.dart';

import 'package:offline_items_app/features/notes/domain/entities/note.dart';

/// Field names of a note inside a `SyncRecord`. Each one is synced and
/// conflict-resolved independently.
abstract final class NoteFields {
  static const String title = 'title';
  static const String body = 'body';

  /// The collection name on the backend.
  static const String collection = 'notes';
}

/// Maps a synced record to the [Note] entity. Nothing outside the data layer
/// sees a `SyncRecord`.
class NoteModel {
  const NoteModel(this._tracked);

  final TrackedRecord _tracked;

  /// Builds the domain entity.
  Note toEntity() {
    final record = _tracked.record;
    final lastEdit = record.lastContentEdit ?? record.lastModified;
    return Note(
      id: record.id,
      title: record.field<String>(NoteFields.title) ?? '',
      body: record.field<String>(NoteFields.body) ?? '',
      updatedAt: (lastEdit?.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0))
          .toLocal(),
      lastEditedByDeviceId: lastEdit?.nodeId ?? '',
      syncState: _tracked.hasPendingChanges
          ? NoteSyncState.pending
          : NoteSyncState.synced,
    );
  }

  /// Visible notes (no tombstones), most recently edited first.
  static List<Note> visibleNotes(List<TrackedRecord> records) {
    final notes = [
      for (final r in records)
        if (!r.record.isDeleted) NoteModel(r).toEntity(),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  /// Builds the change map for a write, including only non-null fields.
  static Map<String, Object?> changes({String? title, String? body}) => {
    NoteFields.title: ?title,
    NoteFields.body: ?body,
  };
}
