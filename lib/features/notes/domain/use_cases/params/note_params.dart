import 'package:core/domain.dart';

import 'package:offline_items_app/features/notes/domain/entities/note.dart';

/// Parameters for `CreateNoteUseCase`.
class CreateNoteParams extends UseCaseParams {
  const CreateNoteParams({required this.title, required this.body});

  /// Raw title as typed.
  final String title;

  /// Raw body as typed.
  final String body;
}

/// Parameters for `UpdateNoteUseCase`.
class UpdateNoteParams extends UseCaseParams {
  const UpdateNoteParams({
    required this.original,
    required this.title,
    required this.body,
  });

  /// The note as it was when the editor opened.
  final Note original;

  /// Edited title.
  final String title;

  /// Edited body.
  final String body;
}

/// Parameters for `DeleteNoteUseCase`.
class DeleteNoteParams extends UseCaseParams {
  const DeleteNoteParams(this.noteId);

  /// Note to delete.
  final String noteId;
}
