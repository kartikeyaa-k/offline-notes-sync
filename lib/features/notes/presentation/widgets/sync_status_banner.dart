import 'package:flutter/material.dart';

import 'package:offline_items_app/features/notes/domain/entities/sync_overview.dart';
import 'package:offline_items_app/features/notes/presentation/widgets/formatting.dart';

/// A one-line banner under the app bar telling the user whether their edits
/// are safe and synced, queued offline, or syncing right now.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    required this.overview,
    required this.onSyncNow,
    super.key,
  });

  /// Current sync state.
  final SyncOverview overview;

  /// Called when the user taps "Sync now".
  final VoidCallback onSyncNow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = overview.pendingChanges;
    final (
      IconData icon,
      Color color,
      String text,
    ) = switch (overview.activity) {
      SyncActivity.syncing => (Icons.sync, scheme.primary, 'Syncing…'),
      SyncActivity.offline => (
        Icons.cloud_off,
        scheme.error,
        pending == 0
            ? 'Offline — edits are saved on this device'
            : 'Offline — $pending change(s) queued',
      ),
      SyncActivity.error => (
        Icons.error_outline,
        scheme.error,
        'Sync failed, retrying${pending > 0 ? ' — $pending queued' : ''}',
      ),
      SyncActivity.idle =>
        pending > 0
            ? (
                Icons.cloud_upload_outlined,
                scheme.tertiary,
                '$pending change(s) waiting to sync',
              )
            : (
                Icons.cloud_done_outlined,
                scheme.primary,
                overview.lastSyncedAt == null
                    ? 'Ready'
                    : 'All synced · ${formatTime(overview.lastSyncedAt!)}',
              ),
    };

    return Semantics(
      liveRegion: true,
      child: Material(
        color: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: color),
                ),
              ),
              TextButton(
                onPressed: overview.activity == SyncActivity.syncing
                    ? null
                    : onSyncNow,
                child: const Text('Sync now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
