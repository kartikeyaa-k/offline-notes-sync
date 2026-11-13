import 'package:core/core.dart';

import '../models/note_model.dart';

/// Mock data: the five notes the mock server starts with on first launch.
///
/// They are written by a pseudo-device `server-seed`, a few days before the
/// demo, so any edit made in the demo is newer and wins.
List<SyncRecord> seedNotes() {
  final base = DateTime.utc(2026, 11, 10, 9).millisecondsSinceEpoch;
  SyncRecord note(int index, String id, String title, String body) {
    final clock = Hlc(
      millis: base + index * 60000,
      counter: 0,
      nodeId: 'server-seed',
    );
    return SyncRecord(
      id: id,
      fields: {
        NoteFields.title: title,
        NoteFields.body: body,
        SyncRecord.deletedField: false,
      },
      clocks: {
        NoteFields.title: clock,
        NoteFields.body: clock,
        SyncRecord.deletedField: clock,
      },
    );
  }

  return [
    note(0, 'seed-groceries', 'Groceries', 'Milk, eggs, bread, coffee beans'),
    note(
      1,
      'seed-standup',
      'Stand-up notes',
      'Yesterday: offline sync.\nToday: conflict tests.',
    ),
    note(
      2,
      'seed-trip',
      'Weekend trip',
      'Book hotel, pack charger, check the weather',
    ),
    note(
      3,
      'seed-books',
      'Books to read',
      'Designing Data-Intensive Applications',
    ),
    note(4, 'seed-ideas', 'App ideas', 'A notes app that works on a plane ✈️'),
  ];
}
