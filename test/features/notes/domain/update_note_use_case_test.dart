// Unit tests for UpdateNoteUseCase: validation and the field-level diff that
// keeps the conflict resolution precise.
import 'package:core/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offline_items_app/features/notes/domain/entities/note.dart';
import 'package:offline_items_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/params/note_params.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/update_note_use_case.dart';

class MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  late MockNotesRepository repository;
  late UpdateNoteUseCase useCase;
  final original = Note(
    id: 'n1',
    title: 'Groceries',
    body: 'Milk',
    updatedAt: DateTime(2026),
    lastEditedByDeviceId: 'device-a',
    syncState: NoteSyncState.synced,
  );

  setUp(() {
    repository = MockNotesRepository();
    useCase = UpdateNoteUseCase(repository);
    when(
      () => repository.updateNote(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => Success(original));
  });

  test('sends only the body when only the body changed', () async {
    await useCase(
      UpdateNoteParams(
        original: original,
        title: 'Groceries',
        body: 'Milk, eggs',
      ),
    );
    verify(() => repository.updateNote(id: 'n1', body: 'Milk, eggs')).called(1);
  });

  test('sends only the title when only the title changed (trimmed)', () async {
    await useCase(
      UpdateNoteParams(original: original, title: '  Food  ', body: 'Milk'),
    );
    verify(() => repository.updateNote(id: 'n1', title: 'Food')).called(1);
  });

  test('does not write anything when nothing changed', () async {
    final result = await useCase(
      UpdateNoteParams(original: original, title: 'Groceries', body: 'Milk'),
    );
    expect(result, isA<Success<Note>>());
    verifyNever(
      () => repository.updateNote(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    );
  });

  test('rejects an empty note', () async {
    final result = await useCase(
      UpdateNoteParams(original: original, title: ' ', body: ''),
    );
    expect(result, isA<Failure<Note>>());
    expect((result as Failure<Note>).code, 'validation');
  });
}
