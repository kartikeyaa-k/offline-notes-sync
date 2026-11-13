import 'field_conflict.dart';
import 'sync_record.dart';

/// A persisted, human-auditable record of a conflict this device was part of.
///
/// Stored in the local store (capped), so the app can show
/// "your title edit was replaced by a newer edit from Device B" even after a
/// restart.
class ConflictLogEntry {
  const ConflictLogEntry({
    required this.id,
    required this.conflict,
    required this.resolvedRecord,
    required this.resolvedAt,
  });

  /// Builds an entry from [toJson] output.
  factory ConflictLogEntry.fromJson(Map<String, Object?> json) =>
      ConflictLogEntry(
        id: json['id']! as String,
        conflict: FieldConflict.fromJson((json['conflict']! as Map).cast()),
        resolvedRecord: SyncRecord.fromJson(
          (json['resolvedRecord']! as Map).cast(),
        ),
        resolvedAt: DateTime.parse(json['resolvedAt']! as String),
      );

  /// Unique id of the log entry.
  final String id;

  /// What clashed and who won.
  final FieldConflict conflict;

  /// The record as it was after resolution (for display, for example its
  /// title).
  final SyncRecord resolvedRecord;

  /// When this device learned about the resolution.
  final DateTime resolvedAt;

  /// Serialises to JSON (JavaScript Object Notation)-safe maps.
  Map<String, Object?> toJson() => {
    'id': id,
    'conflict': conflict.toJson(),
    'resolvedRecord': resolvedRecord.toJson(),
    'resolvedAt': resolvedAt.toIso8601String(),
  };
}
