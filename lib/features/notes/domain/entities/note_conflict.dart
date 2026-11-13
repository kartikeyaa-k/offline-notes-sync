import 'package:equatable/equatable.dart';

/// The part of a note a conflict was about.
enum NoteField { title, body, existence }

/// What clashed.
enum NoteConflictType {
  /// Both devices edited the same field.
  bothEdited,

  /// This device edited; the other device deleted.
  editedButDeletedElsewhere,

  /// This device deleted; the other device edited.
  deletedButEditedElsewhere,
}

/// Who won, from this device's point of view.
enum ConflictOutcome { thisDeviceWon, otherDeviceWon }

/// An automatically resolved conflict, kept so the user can see what
/// happened to their edit. Resolution rule: the most recent *edit* wins
/// (per field), regardless of which device synced first.
class NoteConflict extends Equatable {
  const NoteConflict({
    required this.id,
    required this.noteId,
    required this.noteTitle,
    required this.field,
    required this.type,
    required this.outcome,
    required this.thisDeviceValue,
    required this.otherDeviceValue,
    required this.thisDeviceEditedAt,
    required this.otherDeviceEditedAt,
    required this.otherDeviceId,
    required this.resolvedAt,
  });

  /// Log entry id.
  final String id;

  /// The note concerned.
  final String noteId;

  /// The note title after resolution (for display).
  final String noteTitle;

  /// Which part of the note clashed.
  final NoteField field;

  /// What kind of clash.
  final NoteConflictType type;

  /// Who won.
  final ConflictOutcome outcome;

  /// This device's value (text, or `null` for delete conflicts).
  final String? thisDeviceValue;

  /// The other device's value.
  final String? otherDeviceValue;

  /// When this device's edit was made.
  final DateTime thisDeviceEditedAt;

  /// When the other device's edit was made.
  final DateTime otherDeviceEditedAt;

  /// The other device's id.
  final String otherDeviceId;

  /// When this device learned the outcome.
  final DateTime resolvedAt;

  @override
  List<Object?> get props => [id];
}
