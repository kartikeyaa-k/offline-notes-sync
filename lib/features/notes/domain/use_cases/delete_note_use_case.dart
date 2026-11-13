import 'package:core/domain.dart';

import 'package:offline_items_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/params/note_params.dart';

/// Deletes a note (offline-capable; synced as a tombstone).
class DeleteNoteUseCase extends UseCase<Resource<void>, DeleteNoteParams> {
  const DeleteNoteUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Resource<void>> call(DeleteNoteParams params) =>
      _repository.deleteNote(params.noteId);
}
