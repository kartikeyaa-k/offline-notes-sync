import 'package:flutter/widgets.dart';

import 'package:offline_items_app/app/app.dart';
import 'package:offline_items_app/app/di/app_dependencies.dart';

/// Entry point.
///
/// Pass `--dart-define=REAL_NETWORK=false` to ignore the platform network
/// and drive connectivity only with the demo's per-device switches.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final root = await AppDependencies.init();
  runApp(OfflineNotesApp(root: root));
}
