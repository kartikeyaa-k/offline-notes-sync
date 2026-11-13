import 'package:core/core.dart';

import 'package:offline_items_app/features/notes/domain/entities/sync_overview.dart';

/// Maps the engine's [SyncStatus] to the domain's [SyncOverview].
class SyncOverviewModel {
  const SyncOverviewModel(this._status);

  final SyncStatus _status;

  /// Builds the domain entity.
  SyncOverview toEntity() => SyncOverview(
    activity: switch (_status.phase) {
      SyncPhase.idle => SyncActivity.idle,
      SyncPhase.syncing => SyncActivity.syncing,
      SyncPhase.offline => SyncActivity.offline,
      SyncPhase.error => SyncActivity.error,
    },
    isOnline: _status.isOnline,
    pendingChanges: _status.pendingCount,
    lastSyncedAt: _status.lastSyncedAt,
    errorMessage: _status.lastError,
  );
}
