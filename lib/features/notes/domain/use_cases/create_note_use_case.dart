import 'package:core/domain.dart';

import 'package:offline_items_app/features/notes/domain/entities/note.dart';
import 'package:offline_items_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/note_validation.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/params/note_params.dart';

/// Creates a note. Works offline: the note is saved locally and synced later.
class CreateNoteUseCase extends UseCase<Resource<Note>, CreateNoteParams> {
  const CreateNoteUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Resource<Note>> call(CreateNoteParams params) async {
    final invalid = NoteValidation.validate<Note>(
      title: params.title,
      body: params.body,
    );
    if (invalid != null) return invalid;
    return _repository.createNote(
      title: params.title.trim(),
      body: params.body,
    );
  }
}
