import 'package:equatable/equatable.dart';

import 'package:offline_items_app/features/notes/domain/entities/note.dart';
import 'package:offline_items_app/features/notes/domain/entities/note_conflict.dart';
import 'package:offline_items_app/features/notes/domain/entities/sync_overview.dart';

/// Loading phase of the notes screen.
enum NotesStatus { loading, ready }

/// A one-shot message for the screen to show (for example in a SnackBar).
/// [id] increases with every message, so the same text twice is still shown
/// twice.
class NotesFeedback extends Equatable {
  const NotesFeedback({
    required this.id,
    required this.message,
    this.isError = false,
  });

  final int id;
  final String message;
  final bool isError;

  @override
  List<Object?> get props => [id, message, isError];
}

/// Everything the notes screen renders.
class NotesState extends Equatable {
  const NotesState({
    this.status = NotesStatus.loading,
    this.notes = const [],
    this.overview = const SyncOverview.initial(),
    this.conflicts = const [],
    this.feedback,
  });

  /// Loading or ready.
  final NotesStatus status;

  /// Visible notes, newest edit first.
  final List<Note> notes;

  /// Sync status for the header.
  final SyncOverview overview;

  /// Resolved conflicts, newest first.
  final List<NoteConflict> conflicts;

  /// Latest one-shot message.
  final NotesFeedback? feedback;

  /// Copy helper.
  NotesState copyWith({
    NotesStatus? status,
    List<Note>? notes,
    SyncOverview? overview,
    List<NoteConflict>? conflicts,
    NotesFeedback? feedback,
  }) => NotesState(
    status: status ?? this.status,
    notes: notes ?? this.notes,
    overview: overview ?? this.overview,
    conflicts: conflicts ?? this.conflicts,
    feedback: feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [status, notes, overview, conflicts, feedback];
}
