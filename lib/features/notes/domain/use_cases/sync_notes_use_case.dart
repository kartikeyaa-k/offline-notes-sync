import 'package:core/domain.dart';

import 'package:offline_items_app/features/notes/domain/entities/sync_overview.dart';
import 'package:offline_items_app/features/notes/domain/repositories/notes_repository.dart';

/// Forces a sync cycle (pull-to-refresh / "sync now" button).
class SyncNotesUseCase extends UseCase<Resource<SyncOverview>, NoParams> {
  const SyncNotesUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Resource<SyncOverview>> call(NoParams params) => _repository.syncNow();
}
