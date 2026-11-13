// Integration test of the notes data layer on top of the real core sync
// engine (in-memory storage, mock server, zero latency): edits work offline
// and reconcile when the network returns.
import 'package:core/core.dart';
import 'package:core/mock_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_items_app/features/notes/data/datasources/notes_sync_data_source.dart';
import 'package:offline_items_app/features/notes/data/mock/seed_notes.dart';
import 'package:offline_items_app/features/notes/data/models/note_model.dart';
import 'package:offline_items_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:offline_items_app/features/notes/domain/entities/note.dart';

void main() {
  late MockSyncServer server;
  late SimulatedConnectivityService network;
  late SyncEngine engine;
  late NotesRepositoryImpl repository;

  setUp(() async {
    server = MockSyncServer(storage: InMemoryKeyValueStore());
    await server.open();
    await server.seedIfEmpty(NoteFields.collection, seedNotes());
    network = SimulatedConnectivityService();
    await network.start();
    engine = SyncEngine(
      deviceId: 'device-a',
      store: KeyValueSyncLocalStore(
        storage: InMemoryKeyValueStore(),
        storageKey: 'notes',
      ),
      remote: MockRemoteGateway(
        server: server,
        collection: NoteFields.collection,
        connectivity: network,
        latency: Duration.zero,
      ),
      connectivity: network,
      clock: HlcClock(nodeId: 'device-a'),
      debounce: const Duration(hours: 1),
    );
    await engine.start();
    await engine.syncNow();
    repository = NotesRepositoryImpl(NotesSyncDataSourceImpl(engine));
  });

  tearDown(() => engine.dispose());

  test('loads the five mock notes from the server', () async {
    expect(await repository.watchNotes().first, hasLength(5));
  });

  test('creating offline succeeds locally, is pending, then syncs', () async {
    network.setNetworkEnabled(false);
    final created = await repository.createNote(
      title: 'On a plane',
      body: 'No Wi-Fi',
    );
    expect(created.isSuccess, isTrue);

    var notes = await repository.watchNotes().first;
    expect(notes.first.title, 'On a plane');
    expect(notes.first.syncState, NoteSyncState.pending);
    expect(
      server.snapshot(NoteFields.collection),
      hasLength(5),
    ); // not yet on server

    final offlineSync = await repository.syncNow();
    expect(offlineSync.isFailure, isTrue); // reported, not thrown

    network.setNetworkEnabled(true);
    await engine.syncNow();
    notes = await repository.watchNotes().first;
    expect(notes.first.syncState, NoteSyncState.synced);
    expect(server.snapshot(NoteFields.collection), hasLength(6));
  });

  test('deleting hides the note and syncs a tombstone', () async {
    final note = (await repository.watchNotes().first).first;
    await repository.deleteNote(note.id);
    await engine.syncNow();
    expect(
      (await repository.watchNotes().first).map((n) => n.id),
      isNot(contains(note.id)),
    );
    expect(
      server
          .snapshot(NoteFields.collection)
          .firstWhere((r) => r.id == note.id)
          .isDeleted,
      isTrue,
    );
  });
}
