// Tests for LwwMerger: per-field Last-Writer-Wins (LWW) and its algebraic
// properties (commutative, idempotent), plus delete-versus-edit handling.
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

Hlc t(int millis, String node) => Hlc(millis: millis, counter: 0, nodeId: node);

void main() {
  const merger = LwwMerger();
  final base = SyncRecord(
    id: 'n1',
    fields: const {'title': 'T0', 'body': 'B0', SyncRecord.deletedField: false},
    clocks: {
      'title': t(1, 'seed'),
      'body': t(1, 'seed'),
      SyncRecord.deletedField: t(1, 'seed'),
    },
  );

  test('newer edit wins per field; different fields are both kept', () {
    final a = base.withChanges({'title': 'A'}, t(10, 'a'));
    final b = base.withChanges({'title': 'B', 'body': 'B-body'}, t(5, 'b'));
    final merged = merger.merge(a, b);
    expect(merged.fields['title'], 'A'); // 10 > 5
    expect(merged.fields['body'], 'B-body'); // only b changed it
  });

  test('is commutative and idempotent', () {
    final a = base.withChanges({'title': 'A'}, t(10, 'a'));
    final b = base.withChanges({'body': 'B'}, t(20, 'b'));
    expect(merger.merge(a, b), merger.merge(b, a));
    expect(merger.merge(a, a), a);
  });

  test('a newer edit resurrects an older delete', () {
    final deleted = base.withChanges({
      SyncRecord.deletedField: true,
    }, t(10, 'a'));
    final edited = base.withChanges({'title': 'Keep me'}, t(20, 'b'));
    final merged = merger.merge(deleted, edited);
    expect(merged.isDeleted, isFalse);
    expect(merged.fields['title'], 'Keep me');
  });

  test('a newer delete beats an older edit', () {
    final edited = base.withChanges({'title': 'Old edit'}, t(10, 'b'));
    final deleted = base.withChanges({
      SyncRecord.deletedField: true,
    }, t(20, 'a'));
    expect(merger.merge(edited, deleted).isDeleted, isTrue);
    expect(merger.merge(deleted, edited).isDeleted, isTrue);
  });
}
