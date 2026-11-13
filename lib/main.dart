import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/di/app_dependencies.dart';

/// Entry point.
///
/// Pass `--dart-define=REAL_NETWORK=false` to ignore the platform network
/// and drive connectivity only with the demo's per-device switches.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final root = await AppDependencies.init(
    useRealConnectivity: const bool.fromEnvironment(
      'REAL_NETWORK',
      defaultValue: true,
    ),
  );
  runApp(OfflineNotesApp(root: root));
}
