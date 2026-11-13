import 'package:collection/collection.dart';

import 'package:core/src/clock/hlc.dart';
import 'package:meta/meta.dart';

/// The generic, feature-agnostic unit of synchronisation.
///
/// A [SyncRecord] is a map of named fields where **every field carries its own
/// [Hlc] (Hybrid Logical Clock) timestamp** of the last write to that field.
/// This is a Last-Writer-Wins (LWW) map, a well-known state-based CRDT
/// (Conflict-free Replicated Data Type): merging two copies field by field,
/// keeping the newer clock, always gives the same result whatever the order
/// of merges (see `LwwMerger`).
///
/// Per-field (instead of per-record) clocks are what let two devices edit
/// *different* fields of the same note offline (for example one edits the
/// title, the other the body) and keep both changes.
///
/// Deletion is a field too ([deletedField]), so a delete is just another
/// timestamped write and a deleted record stays as a tombstone that can be
/// synced to other devices.
///
/// Field values must be JSON (JavaScript Object Notation)-safe: `String`,
/// `num`, `bool`, `null`, or lists/maps of those.
@immutable
class SyncRecord {
  const SyncRecord({
    required this.id,
    required this.fields,
    required this.clocks,
    this.version = 0,
  });

  /// An empty record, used before the first local write of a new item.
  const SyncRecord.empty(this.id)
    : fields = const {},
      clocks = const {},
      version = 0;

  /// Builds a record from [toJson] output.
  factory SyncRecord.fromJson(Map<String, Object?> json) {
    final rawClocks = (json['clocks'] as Map?)?.cast<String, Object?>() ?? {};
    return SyncRecord(
      id: json['id']! as String,
      fields: Map<String, Object?>.from((json['fields'] as Map?) ?? const {}),
      clocks: {
        for (final entry in rawClocks.entries)
          entry.key: Hlc.parse(entry.value! as String),
      },
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }

  /// Reserved field name holding the tombstone flag.
  static const String deletedField = '_deleted';

  /// Stable identifier, generated on the client (a UUID, Universally Unique
  /// Identifier) so items can be created offline without asking the server.
  final String id;

  /// Field values by name.
  final Map<String, Object?> fields;

  /// Per-field timestamp of the last write.
  final Map<String, Hlc> clocks;

  /// Server-assigned version: the server's global change sequence number at
  /// the last change of this record. `0` means "never acknowledged by the
  /// server". Used as the delta-pull cursor and for diagnostics.
  final int version;

  /// `true` when the record is a tombstone.
  bool get isDeleted => fields[deletedField] == true;

  /// `true` when the server has acknowledged this record at least once.
  bool get existsOnServer => version > 0;

  /// The newest clock across all fields, or `null` for an empty record.
  Hlc? get lastModified => clocks.values.maxOrNull;

  /// The newest clock across content fields (ignores the tombstone).
  Hlc? get lastContentEdit => clocks.entries
      .where((e) => e.key != deletedField)
      .map((e) => e.value)
      .maxOrNull;

  /// Names of content fields (everything except the tombstone).
  Iterable<String> get contentFieldNames =>
      clocks.keys.where((name) => name != deletedField);

  /// Typed field accessor.
  T? field<T>(String name) {
    final value = fields[name];
    return value is T ? value : null;
  }

  /// Returns a copy with [changes] written at [clock]. Every changed field
  /// gets the same clock, because they were written by the same user action.
  SyncRecord withChanges(Map<String, Object?> changes, Hlc clock) => SyncRecord(
    id: id,
    fields: {...fields, ...changes},
    clocks: {...clocks, for (final name in changes.keys) name: clock},
    version: version,
  );

  /// Copy helper.
  SyncRecord copyWith({
    Map<String, Object?>? fields,
    Map<String, Hlc>? clocks,
    int? version,
  }) => SyncRecord(
    id: id,
    fields: fields ?? this.fields,
    clocks: clocks ?? this.clocks,
    version: version ?? this.version,
  );

  /// Serialises to JSON-safe maps.
  Map<String, Object?> toJson() => {
    'id': id,
    'fields': fields,
    'clocks': {for (final e in clocks.entries) e.key: e.value.pack()},
    'version': version,
  };

  static const _deepEquality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is SyncRecord &&
      other.id == id &&
      other.version == version &&
      _deepEquality.equals(other.fields, fields) &&
      _deepEquality.equals(other.clocks, clocks);

  @override
  int get hashCode => Object.hash(
    id,
    version,
    _deepEquality.hash(fields),
    _deepEquality.hash(clocks),
  );

  @override
  String toString() => 'SyncRecord($id v$version $fields)';
}
