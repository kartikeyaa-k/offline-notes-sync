import 'package:core/domain.dart';

import '../entities/note.dart';
import '../repositories/notes_repository.dart';

/// Streams the notes list from the local source of truth.
class WatchNotesUseCase extends StreamUseCase<List<Note>, NoParams> {
  const WatchNotesUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Stream<List<Note>> call(NoParams params) => _repository.watchNotes();
}
