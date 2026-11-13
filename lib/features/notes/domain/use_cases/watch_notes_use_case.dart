import 'package:core/domain.dart';

import 'package:offline_items_app/features/notes/domain/entities/note.dart';
import 'package:offline_items_app/features/notes/domain/repositories/notes_repository.dart';

/// Streams the notes list from the local source of truth.
class WatchNotesUseCase extends StreamUseCase<List<Note>, NoParams> {
  const WatchNotesUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Stream<List<Note>> call(NoParams params) => _repository.watchNotes();
}
