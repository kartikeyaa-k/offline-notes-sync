import 'package:core/domain.dart';

import 'package:offline_items_app/features/notes/domain/entities/sync_overview.dart';
import 'package:offline_items_app/features/notes/domain/repositories/notes_repository.dart';

/// Streams the sync status.
class WatchSyncOverviewUseCase extends StreamUseCase<SyncOverview, NoParams> {
  const WatchSyncOverviewUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Stream<SyncOverview> call(NoParams params) => _repository.watchSyncOverview();
}
