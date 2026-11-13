import 'package:core/core.dart';
import 'package:core/mock_server.dart';
import 'package:get_it/get_it.dart';

import '../../features/notes/data/mock/seed_notes.dart';
import '../../features/notes/data/models/note_model.dart';

/// App-wide singletons, registered in the root `GetIt` container.
///
/// These are shared by every simulated device:
/// * [KeyValueStore]: one persistent storage (each device and the server use
///   their own key, so their data is still separate);
/// * [ConnectivityService]: the *real* device network, combined with each
///   simulated device's own switch;
/// * [MockSyncServer]: the in-process backend that both devices sync with.
///
/// Why get_it without `injectable` code generation: the demo needs **two
/// independent object graphs of the same types** (one per simulated device).
/// That maps naturally onto `GetIt.asNewInstance()` per device (see
/// `DeviceScope`), and keeps the project free of build_runner. In a
/// single-device production app the same registrations can be moved to
/// `@injectable` annotations unchanged.
abstract final class AppDependencies {
  /// Registers and initialises the shared singletons.
  ///
  /// Set [useRealConnectivity] to `false` to ignore the platform network
  /// (each device is then online only according to its demo switch).
  static Future<GetIt> init({
    GetIt? container,
    KeyValueStore? storage,
    bool useRealConnectivity = true,
  }) async {
    final getIt = container ?? GetIt.instance;
    await getIt.reset();

    final store = storage ?? SharedPreferencesKeyValueStore();
    getIt.registerSingleton<KeyValueStore>(store);

    final ConnectivityService connectivity = useRealConnectivity
        ? DeviceConnectivityService()
        : SimulatedConnectivityService();
    await connectivity.start();
    getIt.registerSingleton<ConnectivityService>(
      connectivity,
      dispose: (c) => c.dispose(),
    );

    final server = MockSyncServer(storage: store);
    await server.open();
    await server.seedIfEmpty(NoteFields.collection, seedNotes());
    getIt.registerSingleton<MockSyncServer>(
      server,
      dispose: (s) => s.dispose(),
    );

    return getIt;
  }
}
