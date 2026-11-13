import 'package:core/domain.dart';

import 'package:offline_items_app/features/notes/domain/entities/note.dart';
import 'package:offline_items_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/note_validation.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/params/note_params.dart';

/// Saves an edited note, sending **only the fields that actually changed**.
///
/// This field-level diff is a business rule, not a detail: if the user only
/// changed the body, the title must not be stamped as edited, otherwise this
/// device would wrongly override a title edit made on another device.
class UpdateNoteUseCase extends UseCase<Resource<Note>, UpdateNoteParams> {
  const UpdateNoteUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Resource<Note>> call(UpdateNoteParams params) async {
    final title = params.title.trim();
    final body = params.body;
    final invalid = NoteValidation.validate<Note>(title: title, body: body);
    if (invalid != null) return invalid;

    final titleChanged = title != params.original.title;
    final bodyChanged = body != params.original.body;
    if (!titleChanged && !bodyChanged) return Success(params.original);

    return _repository.updateNote(
      id: params.original.id,
      title: titleChanged ? title : null,
      body: bodyChanged ? body : null,
    );
  }
}
