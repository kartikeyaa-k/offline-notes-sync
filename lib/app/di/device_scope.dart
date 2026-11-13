import 'package:core/core.dart';
import 'package:core/mock_server.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:offline_items_app/features/notes/data/datasources/notes_sync_data_source.dart';
import 'package:offline_items_app/features/notes/data/models/note_model.dart';
import 'package:offline_items_app/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:offline_items_app/features/notes/domain/repositories/notes_repository.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/create_note_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/delete_note_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/sync_notes_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/update_note_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/watch_note_conflicts_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/watch_notes_use_case.dart';
import 'package:offline_items_app/features/notes/domain/use_cases/watch_sync_overview_use_case.dart';
import 'package:offline_items_app/features/notes/presentation/bloc/notes_cubit.dart';

/// Static description of a simulated device.
class DeviceProfile {
  const DeviceProfile({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  /// Device id; also the HLC (Hybrid Logical Clock) node id stamped on its
  /// edits.
  final String id;

  /// Display name.
  final String name;

  /// Icon in the demo header.
  final IconData icon;

  /// Accent colour in the demo.
  final Color color;
}

/// The complete object graph of **one device**, in its own `GetIt` container.
///
/// Each simulated device gets its own network switch, clock, local store,
/// gateway and sync engine, exactly as if it were a separate phone. Only the
/// [MockSyncServer] and the storage backend are shared (from the root
/// container).
///
/// Layers are wired in the usual Clean Architecture direction:
/// data source (data) → repository (data, as the domain contract) →
/// use cases (domain) → cubit (presentation).
class DeviceScope {
  DeviceScope._(this.profile, this._getIt);

  /// Builds and starts a device.
  static Future<DeviceScope> create(DeviceProfile profile, GetIt root) async {
    final getIt = GetIt.asNewInstance();

    // Core sync infrastructure.
    final network = SimulatedConnectivityService(
      upstream: root<ConnectivityService>(),
    );
    await network.start();
    getIt
      ..registerSingleton<SimulatedConnectivityService>(network)
      ..registerSingleton<HlcClock>(HlcClock(nodeId: profile.id))
      ..registerSingleton<SyncLocalStore>(
        KeyValueSyncLocalStore(
          storage: root<KeyValueStore>(),
          storageKey: 'sync.${profile.id}.${NoteFields.collection}',
        ),
      )
      ..registerSingleton<SyncRemoteGateway>(
        MockRemoteGateway(
          server: root<MockSyncServer>(),
          collection: NoteFields.collection,
          connectivity: network,
        ),
      )
      ..registerSingleton<SyncEngine>(
        SyncEngine(
          deviceId: profile.id,
          store: getIt<SyncLocalStore>(),
          remote: getIt<SyncRemoteGateway>(),
          connectivity: network,
          clock: getIt<HlcClock>(),
        ),
      );

    // Notes feature: data → domain → presentation.
    getIt
      ..registerLazySingleton<NotesSyncDataSource>(
        () => NotesSyncDataSourceImpl(getIt<SyncEngine>()),
      )
      ..registerLazySingleton<NotesRepository>(
        () => NotesRepositoryImpl(getIt<NotesSyncDataSource>()),
      )
      ..registerFactory(() => WatchNotesUseCase(getIt<NotesRepository>()))
      ..registerFactory(
        () => WatchSyncOverviewUseCase(getIt<NotesRepository>()),
      )
      ..registerFactory(
        () => WatchNoteConflictsUseCase(getIt<NotesRepository>()),
      )
      ..registerFactory(() => CreateNoteUseCase(getIt<NotesRepository>()))
      ..registerFactory(() => UpdateNoteUseCase(getIt<NotesRepository>()))
      ..registerFactory(() => DeleteNoteUseCase(getIt<NotesRepository>()))
      ..registerFactory(() => SyncNotesUseCase(getIt<NotesRepository>()))
      ..registerFactory(
        () => NotesCubit(
          watchNotes: getIt(),
          watchSyncOverview: getIt(),
          watchConflicts: getIt(),
          createNote: getIt(),
          updateNote: getIt(),
          deleteNote: getIt(),
          syncNotes: getIt(),
        ),
      );

    await getIt<SyncEngine>().start();
    return DeviceScope._(profile, getIt);
  }

  /// Which device this is.
  final DeviceProfile profile;

  final GetIt _getIt;

  /// The device's network switch (demo control).
  SimulatedConnectivityService get network =>
      _getIt<SimulatedConnectivityService>();

  /// A fresh cubit for this device's notes screen.
  NotesCubit createNotesCubit() => _getIt<NotesCubit>();

  /// Stops the device. With [wipeData], also deletes its local database.
  Future<void> dispose({bool wipeData = false}) async {
    await _getIt<SyncEngine>().dispose();
    final store = _getIt<SyncLocalStore>();
    if (wipeData) await store.clear();
    await store.dispose();
    await network.dispose();
    await _getIt.reset();
  }
}
