import 'dart:async';

import 'package:core/domain.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/note.dart';
import '../../domain/entities/note_conflict.dart';
import '../../domain/use_cases/create_note_use_case.dart';
import '../../domain/use_cases/delete_note_use_case.dart';
import '../../domain/use_cases/params/note_params.dart';
import '../../domain/use_cases/sync_notes_use_case.dart';
import '../../domain/use_cases/update_note_use_case.dart';
import '../../domain/use_cases/watch_note_conflicts_use_case.dart';
import '../../domain/use_cases/watch_notes_use_case.dart';
import '../../domain/use_cases/watch_sync_overview_use_case.dart';
import 'notes_state.dart';

/// State holder for the notes screen.
///
/// It combines three live streams from the domain (notes, sync status,
/// conflict log) into one [NotesState], and forwards user actions to use
/// cases. It never navigates and never touches storage or network directly.
class NotesCubit extends Cubit<NotesState> {
  NotesCubit({
    required this._watchNotes,
    required this._watchSyncOverview,
    required this._watchConflicts,
    required this._createNote,
    required this._updateNote,
    required this._deleteNote,
    required this._syncNotes,
  }) : super(const NotesState());

  final WatchNotesUseCase _watchNotes;
  final WatchSyncOverviewUseCase _watchSyncOverview;
  final WatchNoteConflictsUseCase _watchConflicts;
  final CreateNoteUseCase _createNote;
  final UpdateNoteUseCase _updateNote;
  final DeleteNoteUseCase _deleteNote;
  final SyncNotesUseCase _syncNotes;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  Set<String>? _knownConflictIds;
  int _feedbackId = 0;

  /// Starts listening. Call once, right after creation.
  void start() {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions
      ..add(
        _watchNotes(const NoParams()).listen(
          (notes) =>
              emit(state.copyWith(status: NotesStatus.ready, notes: notes)),
        ),
      )
      ..add(
        _watchSyncOverview(const NoParams())
            .listen((overview) => emit(state.copyWith(overview: overview))),
      )
      ..add(_watchConflicts(const NoParams()).listen(_onConflicts));
  }

  /// Creates a note. Returns `true` on success.
  Future<bool> create({required String title, required String body}) =>
      _handle(_createNote(CreateNoteParams(title: title, body: body)));

  /// Saves edits to [original]. Returns `true` on success.
  Future<bool> update(
    Note original, {
    required String title,
    required String body,
  }) => _handle(
    _updateNote(UpdateNoteParams(original: original, title: title, body: body)),
  );

  /// Deletes [note]. Returns `true` on success.
  Future<bool> delete(Note note) => _handle(
    _deleteNote(DeleteNoteParams(note.id)),
    successMessage: 'Deleted "${note.title.isEmpty ? 'note' : note.title}"',
  );

  /// Forces a sync cycle.
  Future<void> syncNow() async {
    final result = await _syncNotes(const NoParams());
    if (result case Failure(:final message, :final code)) {
      _feedback(message, isError: code != 'offline');
    } else {
      _feedback('Up to date');
    }
  }

  Future<bool> _handle<T>(
    Future<Resource<T>> action, {
    String? successMessage,
  }) async {
    final result = await action;
    switch (result) {
      case Failure(:final message):
        _feedback(message, isError: true);
        return false;
      case Success():
        if (successMessage != null) _feedback(successMessage);
        return true;
      case Loading():
        return false;
    }
  }

  void _onConflicts(List<NoteConflict> conflicts) {
    final known = _knownConflictIds;
    _knownConflictIds = {for (final c in conflicts) c.id};
    emit(state.copyWith(conflicts: conflicts));
    if (known == null) return; // first load: nothing is "new"
    final fresh = conflicts.where((c) => !known.contains(c.id)).toList();
    if (fresh.isEmpty) return;
    final lost = fresh
        .where((c) => c.outcome == ConflictOutcome.otherDeviceWon)
        .length;
    _feedback(
      lost == 0
          ? '${fresh.length} conflict(s) resolved — your newer edit was kept'
          : '${fresh.length} conflict(s) resolved — $lost of your edits were older and replaced',
    );
  }

  void _feedback(String message, {bool isError = false}) {
    if (isClosed) return;
    emit(
      state.copyWith(
        feedback: NotesFeedback(
          id: ++_feedbackId,
          message: message,
          isError: isError,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    return super.close();
  }
}
