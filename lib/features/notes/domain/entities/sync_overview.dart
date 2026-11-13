import 'package:equatable/equatable.dart';

/// What synchronisation is doing right now.
enum SyncActivity { idle, syncing, offline, error }

/// The sync state shown in the notes screen header.
class SyncOverview extends Equatable {
  const SyncOverview({
    required this.activity,
    required this.isOnline,
    required this.pendingChanges,
    this.lastSyncedAt,
    this.errorMessage,
  });

  /// Initial value before the first status arrives.
  const SyncOverview.initial()
    : activity = SyncActivity.idle,
      isOnline = false,
      pendingChanges = 0,
      lastSyncedAt = null,
      errorMessage = null;

  /// Current activity.
  final SyncActivity activity;

  /// Whether the device has connectivity.
  final bool isOnline;

  /// Notes with local changes not yet on the server.
  final int pendingChanges;

  /// Last successful sync.
  final DateTime? lastSyncedAt;

  /// Last error, if any.
  final String? errorMessage;

  @override
  List<Object?> get props => [
    activity,
    isOnline,
    pendingChanges,
    lastSyncedAt,
    errorMessage,
  ];
}
