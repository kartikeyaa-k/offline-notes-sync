import 'package:core/src/clock/hlc.dart';
import 'package:core/src/sync/sync_record.dart';

/// The conflict-resolution rule of the whole system:
/// **per-field Last-Writer-Wins (LWW), where "last" means the latest *edit*
/// (by Hybrid Logical Clock, HLC), not the latest *sync*.**
///
/// For each field the value with the greater [Hlc] wins. Because the merge is
/// a pure function of the two inputs, and is commutative
/// (`merge(a, b) == merge(b, a)`), associative and idempotent
/// (`merge(a, a) == a`), every device and the server end up with exactly the
/// same data no matter in which order they exchange changes, and retrying a
/// sync can never corrupt anything.
///
/// Delete versus edit uses the same idea ("latest intent wins"):
/// * a delete that is newer than every content edit keeps the record deleted;
/// * a content edit that is newer than the delete brings the record back
///   (it is *resurrected*), because the user who edited it clearly still
///   wanted it. No work is silently lost to an older delete.
///
/// The same class runs on the server (when a device pushes) and on devices
/// (when they pull), which is why they always agree.
class LwwMerger {
  const LwwMerger();

  /// Merges two copies of the same record. The result's `version` is the
  /// larger of the two; callers that know the authoritative version (the
  /// server) override it.
  SyncRecord merge(SyncRecord a, SyncRecord b) {
    assert(a.id == b.id, 'Cannot merge different records');
    final fields = <String, Object?>{};
    final clocks = <String, Hlc>{};

    for (final name in {...a.clocks.keys, ...b.clocks.keys}) {
      final clockA = a.clocks[name];
      final clockB = b.clocks[name];
      final takeA = clockB == null || (clockA != null && clockA >= clockB);
      final winner = takeA ? a : b;
      fields[name] = winner.fields[name];
      clocks[name] = winner.clocks[name]!;
    }

    final merged = SyncRecord(
      id: a.id,
      fields: fields,
      clocks: clocks,
      version: a.version > b.version ? a.version : b.version,
    );
    return _resolveDeleteVersusEdit(merged);
  }

  /// "A newer edit beats an older delete": if any content field was written
  /// after the tombstone, the record is un-deleted at that edit's clock.
  SyncRecord _resolveDeleteVersusEdit(SyncRecord record) {
    if (!record.isDeleted) return record;
    final deleteClock = record.clocks[SyncRecord.deletedField]!;
    final lastEdit = record.lastContentEdit;
    if (lastEdit == null || lastEdit <= deleteClock) return record;
    return record.copyWith(
      fields: {...record.fields, SyncRecord.deletedField: false},
      clocks: {...record.clocks, SyncRecord.deletedField: lastEdit},
    );
  }
}
