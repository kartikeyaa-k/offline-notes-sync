// End-to-end scenarios: two devices share one MockSyncServer. One goes
// offline, both edit, then it reconnects. These tests are the executable
// specification of "who wins".
import 'package:core/core.dart';
import 'package:core/mock_server.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared fake wall clock (milliseconds), advanced by the tests.
int wallClock = 0;

class TestDevice {
  TestDevice._(this.id, this.network, this.gateway, this.engine);

  static Future<TestDevice> create(MockSyncServer server, String id) async {
    final network = SimulatedConnectivityService();
    await network.start();
    final gateway = MockRemoteGateway(
      server: server,
      collection: 'notes',
      connectivity: network,
      latency: Duration.zero,
    );
    final engine = SyncEngine(
      deviceId: id,
      store: KeyValueSyncLocalStore(
        storage: InMemoryKeyValueStore(),
        storageKey: 'sync.$id.notes',
      ),
      remote: gateway,
      connectivity: network,
      clock: HlcClock(nodeId: id, wallClock: () => wallClock),
      // Long debounce so only the test decides when a sync runs.
      debounce: const Duration(hours: 1),
    );
    await engine.start();
    await engine.syncNow();
    return TestDevice._(id, network, gateway, engine);
  }

  final String id;
  final SimulatedConnectivityService network;
  final MockRemoteGateway gateway;
  final SyncEngine engine;

  SyncRecord note(String noteId) =>
      engine.records.firstWhere((r) => r.record.id == noteId).record;

  Future<void> goOffline() async => network.setNetworkEnabled(enabled: false);

  Future<SyncReport> goOnlineAndSync() async {
    network.setNetworkEnabled(enabled: true);
    return engine.syncNow();
  }

  Future<void> dispose() => engine.dispose();
}

void main() {
  late MockSyncServer server;
  late TestDevice a;
  late TestDevice b;

  setUp(() async {
    wallClock = 1000;
    server = MockSyncServer(storage: InMemoryKeyValueStore());
    await server.open();
    const seed = Hlc(millis: 500, counter: 0, nodeId: 'seed');
    await server.seedIfEmpty('notes', [
      const SyncRecord(
        id: 'n1',
        fields: {
          'title': 'Groceries',
          'body': 'Milk',
          SyncRecord.deletedField: false,
        },
        clocks: {'title': seed, 'body': seed, SyncRecord.deletedField: seed},
      ),
    ]);
    a = await TestDevice.create(server, 'device-a');
    b = await TestDevice.create(server, 'device-b');
  });

  tearDown(() async {
    await a.dispose();
    await b.dispose();
    await server.dispose();
  });

  test('both devices start with the seeded note', () {
    expect(a.note('n1').fields['title'], 'Groceries');
    expect(b.note('n1').fields['title'], 'Groceries');
  });

  test(
    'same field: the offline edit made LATER wins, even though it syncs later',
    () async {
      await b.goOffline();

      wallClock = 2000;
      await a.engine.write('n1', {'title': 'A title (10:00)'});
      await a.engine.syncNow();

      wallClock = 3000; // B edits after A, while offline
      await b.engine.write('n1', {'title': 'B title (10:05)'});

      wallClock = 9000; // B reconnects much later
      final report = await b.goOnlineAndSync();
      await a.engine.syncNow();

      expect(a.note('n1').fields['title'], 'B title (10:05)');
      expect(b.note('n1').fields['title'], 'B title (10:05)');
      expect(report.conflicts.single.kind, ConflictKind.concurrentEdit);
      expect(report.conflicts.single.winner, ConflictWinner.local);
    },
  );

  test(
    'same field: the offline edit made EARLIER loses to the newer online edit',
    () async {
      await b.goOffline();

      wallClock = 2000; // B edits first, offline
      await b.engine.write('n1', {'title': 'B title (10:00)'});

      wallClock = 3000; // A edits later, online
      await a.engine.write('n1', {'title': 'A title (10:05)'});
      await a.engine.syncNow();

      wallClock = 9000;
      final report = await b.goOnlineAndSync();

      expect(b.note('n1').fields['title'], 'A title (10:05)');
      expect(report.conflicts.single.winner, ConflictWinner.remote);
      final log = b.engine.watchConflicts();
      expect((await log.first).single.conflict.remoteValue, 'A title (10:05)');
    },
  );

  test(
    'different fields edited on each device are both kept (no conflict)',
    () async {
      await b.goOffline();
      wallClock = 2000;
      await a.engine.write('n1', {'title': 'Weekly groceries'});
      await a.engine.syncNow();
      wallClock = 3000;
      await b.engine.write('n1', {'body': 'Milk, eggs, bread'});

      final report = await b.goOnlineAndSync();
      await a.engine.syncNow();

      for (final device in [a, b]) {
        expect(device.note('n1').fields['title'], 'Weekly groceries');
        expect(device.note('n1').fields['body'], 'Milk, eggs, bread');
      }
      expect(report.conflicts, isEmpty);
    },
  );

  test('edit after delete: the newer edit brings the note back', () async {
    await b.goOffline();
    wallClock = 2000;
    await a.engine.delete('n1');
    await a.engine.syncNow();
    wallClock = 3000;
    await b.engine.write('n1', {'body': 'Still needed!'});

    final report = await b.goOnlineAndSync();
    await a.engine.syncNow();

    expect(a.note('n1').isDeleted, isFalse);
    expect(a.note('n1').fields['body'], 'Still needed!');
    expect(report.conflicts.single.kind, ConflictKind.editVersusDelete);
    expect(report.conflicts.single.winner, ConflictWinner.local);
  });

  test('delete after edit: the newer delete wins', () async {
    await b.goOffline();
    wallClock = 2000;
    await b.engine.write('n1', {'body': 'Old offline edit'});
    wallClock = 3000;
    await a.engine.delete('n1');
    await a.engine.syncNow();

    final report = await b.goOnlineAndSync();

    expect(b.note('n1').isDeleted, isTrue);
    expect(report.conflicts.single.winner, ConflictWinner.remote);
  });

  test(
    'a lost response is retried safely thanks to the idempotency key',
    () async {
      wallClock = 2000;
      await a.engine.write('n1', {'title': 'Once'});
      a.gateway.dropNextResponse();
      await a.engine.syncNow(); // server applied it, device never heard back
      expect(a.engine.status.pendingCount, 1);
      final versionAfterFirst = server.currentVersion;

      final report = await a.engine.syncNow(); // retry, same opId
      expect(a.engine.status.pendingCount, 0);
      expect(server.currentVersion, versionAfterFirst); // not applied twice
      expect(report.conflicts, isEmpty);
    },
  );

  test('items created offline on both devices end up on both', () async {
    await a.goOffline();
    await b.goOffline();
    wallClock = 2000;
    await a.engine.write('from-a', {'title': 'Created on A'});
    await b.engine.write('from-b', {'title': 'Created on B'});

    await a.goOnlineAndSync();
    await b.goOnlineAndSync();
    await a.engine.syncNow();

    for (final device in [a, b]) {
      final ids = device.engine.records.map((r) => r.record.id).toSet();
      expect(ids, containsAll(['n1', 'from-a', 'from-b']));
    }
  });

  test('all replicas converge to the server state', () async {
    await b.goOffline();
    wallClock = 2000;
    await a.engine.write('n1', {'title': 'x'});
    await a.engine.syncNow();
    wallClock = 2500;
    await b.engine.write('n1', {'title': 'y', 'body': 'z'});
    await b.goOnlineAndSync();
    await a.engine.syncNow();

    final serverCopy = server.snapshot('notes').single;
    expect(a.note('n1'), serverCopy);
    expect(b.note('n1'), serverCopy);
  });
}
