import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:offline_items_app/app/demo/sync_playground_screen.dart';

/// Root widget.
class OfflineNotesApp extends StatelessWidget {
  const OfflineNotesApp({required this.root, super.key});

  /// Root dependency container.
  final GetIt root;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3F6CD8);
    return MaterialApp(
      title: 'Offline Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: SyncPlaygroundScreen(root: root),
    );
  }
}
