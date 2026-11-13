import 'package:core/src/sync/field_conflict.dart';

/// What the sync engine is doing right now.
enum SyncPhase {
  /// Online and up to date (or waiting for the next trigger).
  idle,

  /// A push/pull cycle is running.
  syncing,

  /// No connectivity: edits are saved locally and queued in the outbox.
  offline,

  /// The last cycle failed for a non-network reason; a retry is scheduled.
  error,
}

/// A snapshot of the engine state, for the UI (User Interface).
class SyncStatus {
  const SyncStatus({
    required this.phase,
    required this.isOnline,
    required this.pendingCount,
    this.lastSyncedAt,
    this.lastError,
  });

  /// Current activity.
  final SyncPhase phase;

  /// Whether the device currently has connectivity.
  final bool isOnline;

  /// Number of records with unsynced local changes.
  final int pendingCount;

  /// When the last successful cycle finished.
  final DateTime? lastSyncedAt;

  /// Message of the last failure, if any.
  final String? lastError;

  /// Copy helper. Pass `clearError: true` to drop [lastError].
  SyncStatus copyWith({
    SyncPhase? phase,
    bool? isOnline,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearError = false,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    isOnline: isOnline ?? this.isOnline,
    pendingCount: pendingCount ?? this.pendingCount,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );

  @override
  String toString() =>
      'SyncStatus(${phase.name}, online=$isOnline, pending=$pendingCount)';
}

/// The outcome of one sync cycle.
class SyncReport {
  const SyncReport({
    required this.pushed,
    required this.pulled,
    required this.conflicts,
    this.skippedOffline = false,
  });

  /// A cycle that did not run because the device is offline.
  const SyncReport.offline()
    : pushed = 0,
      pulled = 0,
      conflicts = const [],
      skippedOffline = true;

  /// Number of outbox entries pushed.
  final int pushed;

  /// Number of records received by the delta pull.
  final int pulled;

  /// Conflicts resolved during this cycle.
  final List<FieldConflict> conflicts;

  /// `true` when nothing ran because the device was offline.
  final bool skippedOffline;
}
