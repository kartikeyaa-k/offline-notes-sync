import 'package:core/core.dart';
import 'package:offline_items_app/features/notes/data/models/note_model.dart';
import 'package:offline_items_app/features/notes/domain/entities/note_conflict.dart';

/// Maps a generic [ConflictLogEntry] from the sync engine to the notes
/// domain's [NoteConflict].
class NoteConflictModel {
  const NoteConflictModel(this._entry);

  final ConflictLogEntry _entry;

  /// Builds the domain entity.
  NoteConflict toEntity() {
    final c = _entry.conflict;
    return NoteConflict(
      id: _entry.id,
      noteId: c.recordId,
      noteTitle:
          _entry.resolvedRecord.field<String>(NoteFields.title) ?? '(untitled)',
      field: switch (c.field) {
        NoteFields.title => NoteField.title,
        NoteFields.body => NoteField.body,
        _ => NoteField.existence,
      },
      type: switch (c.kind) {
        ConflictKind.concurrentEdit => NoteConflictType.bothEdited,
        ConflictKind.editVersusDelete =>
          NoteConflictType.editedButDeletedElsewhere,
        ConflictKind.deleteVersusEdit =>
          NoteConflictType.deletedButEditedElsewhere,
      },
      outcome: c.winner == ConflictWinner.local
          ? ConflictOutcome.thisDeviceWon
          : ConflictOutcome.otherDeviceWon,
      thisDeviceValue: c.localValue is String ? c.localValue! as String : null,
      otherDeviceValue: c.remoteValue is String
          ? c.remoteValue! as String
          : null,
      thisDeviceEditedAt: c.localClock.dateTime.toLocal(),
      otherDeviceEditedAt: c.remoteClock.dateTime.toLocal(),
      otherDeviceId: c.remoteClock.nodeId,
      resolvedAt: _entry.resolvedAt,
    );
  }
}
