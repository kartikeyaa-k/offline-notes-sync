import 'package:core/domain.dart';

import 'package:offline_items_app/features/notes/domain/entities/note_conflict.dart';
import 'package:offline_items_app/features/notes/domain/repositories/notes_repository.dart';

/// Streams the log of resolved conflicts.
class WatchNoteConflictsUseCase
    extends StreamUseCase<List<NoteConflict>, NoParams> {
  const WatchNoteConflictsUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Stream<List<NoteConflict>> call(NoParams params) =>
      _repository.watchConflicts();
}
