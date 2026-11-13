import '../../clock/hlc.dart';
import '../field_conflict.dart';
import '../sync_record.dart';

/// The contract between a device and the sync backend, for one collection
/// (for example `notes`).
///
/// A real implementation would be a REST (Representational State Transfer) or
/// gRPC client; this project ships an in-process mock (`MockRemoteGateway`).
/// The sync engine depends only on this interface.
abstract interface class SyncRemoteGateway {
  /// Sends one pending change. The server merges it with its copy (using the
  /// same `LwwMerger` as devices), assigns a new version, and returns the
  /// merged record plus any conflicts it detected.
  ///
  /// Throws [NetworkException] when the server cannot be reached.
  Future<PushResponse> push(PushRequest request);

  /// Returns records changed after the server version [since] (a delta pull,
  /// including tombstones), at most [limit] per page.
  ///
  /// Throws [NetworkException] when the server cannot be reached.
  Future<PullResponse> pull({required int since, int limit = 100});

  /// Notifications that the server changed, as a real backend would send
  /// through a WebSocket or a silent push notification. The engine reacts
  /// by pulling, so an online device sees the other device's edits quickly.
  Stream<ServerChange> get serverChanges;
}

/// One pushed change.
class PushRequest {
  const PushRequest({
    required this.opId,
    required this.deviceId,
    required this.record,
    required this.dirtyFields,
    required this.baseClocks,
    required this.baseVersion,
  });

  /// Builds a request from [toJson] output.
  factory PushRequest.fromJson(Map<String, Object?> json) => PushRequest(
    opId: json['opId']! as String,
    deviceId: json['deviceId']! as String,
    record: SyncRecord.fromJson((json['record']! as Map).cast()),
    dirtyFields: {...(json['dirtyFields']! as List).cast<String>()},
    baseClocks: {
      for (final e
          in (json['baseClocks']! as Map).cast<String, Object?>().entries)
        e.key: Hlc.parse(e.value! as String),
    },
    baseVersion: (json['baseVersion']! as num).toInt(),
  );

  /// Idempotency key (see `OutboxEntry.opId`).
  final String opId;

  /// The device sending the change.
  final String deviceId;

  /// The device's full current copy, with per-field clocks.
  final SyncRecord record;

  /// Fields the device changed.
  final Set<String> dirtyFields;

  /// Clocks the device's change was based on (for conflict detection).
  final Map<String, Hlc> baseClocks;

  /// Server version the device's change was based on.
  final int baseVersion;

  /// Serialises to JSON (JavaScript Object Notation)-safe maps.
  Map<String, Object?> toJson() => {
    'opId': opId,
    'deviceId': deviceId,
    'record': record.toJson(),
    'dirtyFields': dirtyFields.toList(),
    'baseClocks': {for (final e in baseClocks.entries) e.key: e.value.pack()},
    'baseVersion': baseVersion,
  };
}

/// The server's answer to a [PushRequest].
class PushResponse {
  const PushResponse({
    required this.record,
    required this.conflicts,
    this.wasDuplicate = false,
  });

  /// Builds a response from [toJson] output.
  factory PushResponse.fromJson(Map<String, Object?> json) => PushResponse(
    record: SyncRecord.fromJson((json['record']! as Map).cast()),
    conflicts: [
      for (final c in (json['conflicts']! as List))
        FieldConflict.fromJson((c as Map).cast()),
    ],
    wasDuplicate: json['wasDuplicate'] as bool? ?? false,
  );

  /// The authoritative merged record with its new server version.
  final SyncRecord record;

  /// Conflicts detected and resolved while merging.
  final List<FieldConflict> conflicts;

  /// `true` when the server had already processed this `opId` and replayed
  /// the stored response (a retried request).
  final bool wasDuplicate;

  /// Returns a copy flagged as a replay.
  PushResponse asDuplicate() =>
      PushResponse(record: record, conflicts: conflicts, wasDuplicate: true);

  /// Serialises to JSON-safe maps.
  Map<String, Object?> toJson() => {
    'record': record.toJson(),
    'conflicts': [for (final c in conflicts) c.toJson()],
    'wasDuplicate': wasDuplicate,
  };
}

/// One page of a delta pull.
class PullResponse {
  const PullResponse({
    required this.records,
    required this.cursor,
    required this.hasMore,
  });

  /// Changed records (including tombstones), ordered by version.
  final List<SyncRecord> records;

  /// The version to pass as `since` on the next pull.
  final int cursor;

  /// `true` when another page is available right away.
  final bool hasMore;
}

/// A "something changed on the server" notification.
class ServerChange {
  const ServerChange({required this.version, required this.originDeviceId});

  /// The new server version.
  final int version;

  /// The device whose push caused the change (devices ignore their own).
  final String originDeviceId;
}

/// Thrown when the backend cannot be reached (offline, timeout, dropped
/// connection). The engine treats it as retryable and keeps the outbox.
class NetworkException implements Exception {
  const NetworkException([this.message = 'Network unavailable']);

  /// Description of the failure.
  final String message;

  @override
  String toString() => 'NetworkException: $message';
}
