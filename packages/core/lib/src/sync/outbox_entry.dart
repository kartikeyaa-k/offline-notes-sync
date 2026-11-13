import 'package:core/src/clock/hlc.dart';

/// A pending local change waiting to be pushed to the server.
///
/// The outbox holds **at most one entry per record**. Several offline edits to
/// the same record are coalesced into one entry (their field names are
/// unioned into [dirtyFields]); the record itself already holds the latest
/// values and clocks, so nothing is lost by coalescing.
///
/// The outbox is written in the same atomic commit as the record change, so
/// a crash can never leave an edit that is saved locally but forgotten by
/// sync.
class OutboxEntry {
  const OutboxEntry({
    required this.recordId,
    required this.opId,
    required this.dirtyFields,
    required this.baseClocks,
    required this.baseVersion,
    required this.revision,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  /// Builds an entry from [toJson] output.
  factory OutboxEntry.fromJson(Map<String, Object?> json) => OutboxEntry(
    recordId: json['recordId']! as String,
    opId: json['opId']! as String,
    dirtyFields: {...(json['dirtyFields']! as List).cast<String>()},
    baseClocks: {
      for (final e
          in (json['baseClocks']! as Map).cast<String, Object?>().entries)
        e.key: Hlc.parse(e.value! as String),
    },
    baseVersion: (json['baseVersion']! as num).toInt(),
    revision: (json['revision']! as num).toInt(),
    createdAt: DateTime.parse(json['createdAt']! as String),
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    lastError: json['lastError'] as String?,
  );

  /// The record this change belongs to.
  final String recordId;

  /// Idempotency key. The server remembers processed keys, so if the network
  /// drops after the server applied a push but before the device got the
  /// response, the retry with the same key returns the stored result instead
  /// of applying the change twice. A new key is generated whenever the entry's
  /// content changes ([revision] increments).
  final String opId;

  /// Fields changed locally since the last successful push.
  final Set<String> dirtyFields;

  /// Per-field clocks of the record when the first pending edit was made:
  /// the "base" the edit was made on. The server compares its clocks to these
  /// to detect concurrent edits by other devices.
  final Map<String, Hlc> baseClocks;

  /// The record's server version when the first pending edit was made.
  final int baseVersion;

  /// Incremented on every local edit coalesced into this entry. After a push
  /// the entry is removed only if no newer edit arrived meanwhile.
  final int revision;

  /// When the entry was first queued (orders the push queue).
  final DateTime createdAt;

  /// Failed push attempts (diagnostics and backoff).
  final int attempts;

  /// Last push error message, if any.
  final String? lastError;

  /// Copy helper.
  OutboxEntry copyWith({
    String? opId,
    Set<String>? dirtyFields,
    Map<String, Hlc>? baseClocks,
    int? baseVersion,
    int? revision,
    int? attempts,
    String? lastError,
  }) => OutboxEntry(
    recordId: recordId,
    opId: opId ?? this.opId,
    dirtyFields: dirtyFields ?? this.dirtyFields,
    baseClocks: baseClocks ?? this.baseClocks,
    baseVersion: baseVersion ?? this.baseVersion,
    revision: revision ?? this.revision,
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError ?? this.lastError,
  );

  /// Serialises to JSON (JavaScript Object Notation)-safe maps.
  Map<String, Object?> toJson() => {
    'recordId': recordId,
    'opId': opId,
    'dirtyFields': dirtyFields.toList(),
    'baseClocks': {for (final e in baseClocks.entries) e.key: e.value.pack()},
    'baseVersion': baseVersion,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'attempts': attempts,
    'lastError': lastError,
  };
}
