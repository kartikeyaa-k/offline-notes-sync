import 'package:core/domain.dart';

import '../repositories/notes_repository.dart';
import 'params/note_params.dart';

/// Deletes a note (offline-capable; synced as a tombstone).
class DeleteNoteUseCase extends UseCase<Resource<void>, DeleteNoteParams> {
  const DeleteNoteUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Resource<void>> call(DeleteNoteParams params) =>
      _repository.deleteNote(params.noteId);
}
