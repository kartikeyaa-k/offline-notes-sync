import 'package:core/src/clock/hlc.dart';
import 'package:core/src/sync/sync_record.dart';

/// What kind of concurrent change was detected.
enum ConflictKind {
  /// Both devices changed the same field since the pushing device last synced.
  concurrentEdit,

  /// The pushing device edited the record; another device deleted it.
  editVersusDelete,

  /// The pushing device deleted the record; another device edited it.
  deleteVersusEdit,
}

/// Which side won, seen from the device that pushed the change.
enum ConflictWinner {
  /// The pushing device's change was kept.
  local,

  /// The other device's change (already on the server) was kept.
  remote,
}

/// One detected and already-resolved conflict.
///
/// Conflicts are *resolved automatically* by `LwwMerger`; this object only
/// reports what happened so the app can tell the user (and so you can audit
/// it). Nothing waits for user input.
class FieldConflict {
  const FieldConflict({
    required this.recordId,
    required this.field,
    required this.kind,
    required this.winner,
    required this.localValue,
    required this.remoteValue,
    required this.localClock,
    required this.remoteClock,
  });

  /// Builds a conflict from [toJson] output.
  factory FieldConflict.fromJson(Map<String, Object?> json) => FieldConflict(
    recordId: json['recordId']! as String,
    field: json['field']! as String,
    kind: ConflictKind.values.byName(json['kind']! as String),
    winner: ConflictWinner.values.byName(json['winner']! as String),
    localValue: json['localValue'],
    remoteValue: json['remoteValue'],
    localClock: Hlc.parse(json['localClock']! as String),
    remoteClock: Hlc.parse(json['remoteClock']! as String),
  );

  /// The record the conflict happened on.
  final String recordId;

  /// The field in conflict ([SyncRecord.deletedField] for delete conflicts).
  final String field;

  /// The kind of concurrent change.
  final ConflictKind kind;

  /// Who won.
  final ConflictWinner winner;

  /// The pushing device's value.
  final Object? localValue;

  /// The value the server already had (from another device).
  final Object? remoteValue;

  /// When the pushing device made its edit.
  final Hlc localClock;

  /// When the other device made its edit.
  final Hlc remoteClock;

  /// Serialises to JSON (JavaScript Object Notation)-safe maps.
  Map<String, Object?> toJson() => {
    'recordId': recordId,
    'field': field,
    'kind': kind.name,
    'winner': winner.name,
    'localValue': localValue,
    'remoteValue': remoteValue,
    'localClock': localClock.pack(),
    'remoteClock': remoteClock.pack(),
  };

  @override
  String toString() =>
      'FieldConflict($recordId.$field ${kind.name} winner=${winner.name})';
}

/// Detects which of a pushed change's fields clashed with changes another
/// device made in the meantime.
///
/// Detection is separate from resolution on purpose: the merge result is the
/// same whether or not we detect anything; detection only explains it.
///
/// How "in the meantime" is known: when a device first edits a record
/// offline, its outbox stores the record's per-field clocks at that moment
/// (`baseClocks`, the version the edit was based on). On push, a field on the
/// server whose clock differs from that base was written by someone else
/// after the device's base, so it is a real concurrent edit and not just
/// stale data.
class ConflictDetector {
  const ConflictDetector();

  /// Returns the conflicts between a pushed record and the server copy.
  ///
  /// * [existing]: the server copy before the push.
  /// * [incoming]: the pushing device's record.
  /// * [merged]: the result of merging the two (to read off the winner).
  /// * [dirtyFields]: the fields the pushing device changed.
  /// * [baseClocks]: the clocks the device's edits were based on.
  /// * [pushingNodeId]: writes by the same device are never conflicts (this
  ///   covers a retry after a lost response).
  List<FieldConflict> detect({
    required SyncRecord existing,
    required SyncRecord incoming,
    required SyncRecord merged,
    required Set<String> dirtyFields,
    required Map<String, Hlc> baseClocks,
    required String pushingNodeId,
  }) {
    bool changedByOthersSinceBase(String field) {
      final serverClock = existing.clocks[field];
      if (serverClock == null || serverClock.nodeId == pushingNodeId) {
        return false;
      }
      return serverClock != baseClocks[field];
    }

    const deleted = SyncRecord.deletedField;
    final contentDirty = dirtyFields.where((f) => f != deleted).toList();
    final conflicts = <FieldConflict>[];

    final localDeleted = dirtyFields.contains(deleted) && incoming.isDeleted;
    if (localDeleted) {
      // This device deleted; did someone else edit it meanwhile?
      final remoteEdits = existing.contentFieldNames
          .where(changedByOthersSinceBase)
          .map((f) => existing.clocks[f]!)
          .toList();
      if (remoteEdits.isNotEmpty) {
        remoteEdits.sort();
        conflicts.add(
          FieldConflict(
            recordId: existing.id,
            field: deleted,
            kind: ConflictKind.deleteVersusEdit,
            winner: merged.isDeleted
                ? ConflictWinner.local
                : ConflictWinner.remote,
            localValue: true,
            remoteValue: false,
            localClock: incoming.clocks[deleted]!,
            remoteClock: remoteEdits.last,
          ),
        );
      }
      return conflicts;
    }

    // This device edited; did someone else delete it meanwhile?
    if (contentDirty.isNotEmpty &&
        existing.isDeleted &&
        changedByOthersSinceBase(deleted)) {
      final localEdit = contentDirty.map((f) => incoming.clocks[f]!).toList()
        ..sort();
      conflicts.add(
        FieldConflict(
          recordId: existing.id,
          field: deleted,
          kind: ConflictKind.editVersusDelete,
          winner: merged.isDeleted
              ? ConflictWinner.remote
              : ConflictWinner.local,
          localValue: false,
          remoteValue: true,
          localClock: localEdit.last,
          remoteClock: existing.clocks[deleted]!,
        ),
      );
    }

    // Same field changed on both sides.
    for (final field in contentDirty) {
      if (!changedByOthersSinceBase(field)) continue;
      // Both made the identical change: nothing to resolve.
      if (existing.fields[field] == incoming.fields[field]) continue;
      conflicts.add(
        FieldConflict(
          recordId: existing.id,
          field: field,
          kind: ConflictKind.concurrentEdit,
          winner: merged.clocks[field] == incoming.clocks[field]
              ? ConflictWinner.local
              : ConflictWinner.remote,
          localValue: incoming.fields[field],
          remoteValue: existing.fields[field],
          localClock: incoming.clocks[field]!,
          remoteClock: existing.clocks[field]!,
        ),
      );
    }
    return conflicts;
  }
}
