// Cubit tests: state is combined from the domain streams, and failures
// become feedback messages instead of exceptions.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:core/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offline_items_app/features/notes/domain/entities/note.dart';
import 'package:offline_items_app/features/notes/domain/entities/note_conflict.dart';
import 'package:offline_items_app/features/notes/domain/entities/sync_overview.dart';
import 'package:offline_items_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/create_note_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/delete_note_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/sync_notes_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/update_note_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/watch_note_conflicts_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/watch_notes_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/watch_sync_overview_use_case.dart';
import 'package:offline_items_app/features/notes/presentation/bloc/notes_cubit.dart';
import 'package:offline_items_app/features/notes/presentation/bloc/notes_state.dart';

class MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  late MockNotesRepository repository;
  late StreamController<List<Note>> notes;

  final note = Note(
    id: 'n1',
    title: 'Groceries',
    body: 'Milk',
    updatedAt: DateTime(2026),
    lastEditedByDeviceId: 'device-a',
    syncState: NoteSyncState.synced,
  );

  NotesCubit build() => NotesCubit(
    watchNotes: WatchNotesUseCase(repository),
    watchSyncOverview: WatchSyncOverviewUseCase(repository),
    watchConflicts: WatchNoteConflictsUseCase(repository),
    createNote: CreateNoteUseCase(repository),
    updateNote: UpdateNoteUseCase(repository),
    deleteNote: DeleteNoteUseCase(repository),
    syncNotes: SyncNotesUseCase(repository),
  );

  setUp(() {
    repository = MockNotesRepository();
    notes = StreamController<List<Note>>();
    when(() => repository.watchNotes()).thenAnswer((_) => notes.stream);
    when(() => repository.watchSyncOverview())
        .thenAnswer((_) => const Stream<SyncOverview>.empty());
    when(() => repository.watchConflicts())
        .thenAnswer((_) => const Stream<List<NoteConflict>>.empty());
  });

  blocTest<NotesCubit, NotesState>(
    'emits ready with notes from the local stream',
    build: build,
    act: (cubit) {
      cubit.start();
      notes.add([note]);
    },
    expect: () => [
      isA<NotesState>()
          .having((s) => s.status, 'status', NotesStatus.ready)
          .having((s) => s.notes, 'notes', [note]),
    ],
  );

  blocTest<NotesCubit, NotesState>(
    'shows an offline message (not an error) when sync is skipped offline',
    build: build,
    setUp: () => when(() => repository.syncNow()).thenAnswer(
      (_) async => const Failure('You are offline.', code: 'offline'),
    ),
    act: (cubit) => cubit.syncNow(),
    expect: () => [
      isA<NotesState>()
          .having((s) => s.feedback?.message, 'message', 'You are offline.')
          .having((s) => s.feedback?.isError, 'isError', false),
    ],
  );

  blocTest<NotesCubit, NotesState>(
    'reports a validation failure from create as an error',
    build: build,
    act: (cubit) => cubit.create(title: '', body: ''),
    expect: () => [
      isA<NotesState>().having((s) => s.feedback?.isError, 'isError', true),
    ],
  );
}
