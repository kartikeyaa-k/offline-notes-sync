import 'package:core/domain.dart';

import '../entities/note_conflict.dart';
import '../repositories/notes_repository.dart';

/// Streams the log of resolved conflicts.
class WatchNoteConflictsUseCase
    extends StreamUseCase<List<NoteConflict>, NoParams> {
  const WatchNoteConflictsUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Stream<List<NoteConflict>> call(NoParams params) =>
      _repository.watchConflicts();
}
