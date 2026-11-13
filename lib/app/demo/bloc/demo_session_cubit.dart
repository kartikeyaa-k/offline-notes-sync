import 'package:core/mock_server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../features/notes/data/mock/seed_notes.dart';
import '../../../features/notes/data/models/note_model.dart';
import '../../di/device_scope.dart';

/// The two simulated devices of the demo.
const demoDevices = [
  DeviceProfile(
    id: 'device-a',
    name: 'Phone A',
    icon: Icons.smartphone,
    color: Color(0xFF3F6CD8),
  ),
  DeviceProfile(
    id: 'device-b',
    name: 'Tablet B',
    icon: Icons.tablet_mac,
    color: Color(0xFFB4562E),
  ),
];

/// Display name for a device id (falls back to the id itself).
String demoDeviceName(String deviceId) => switch (deviceId) {
  'server-seed' => 'mock data',
  _ => demoDevices.where((d) => d.id == deviceId).firstOrNull?.name ?? deviceId,
};

/// State of the demo session.
sealed class DemoSessionState {
  const DemoSessionState();
}

/// Devices are starting (or resetting).
final class DemoSessionLoading extends DemoSessionState {
  const DemoSessionLoading();
}

/// Devices are running. [generation] changes on every reset so widgets
/// rebuild with fresh cubits.
final class DemoSessionReady extends DemoSessionState {
  const DemoSessionReady(this.devices, this.generation);

  final List<DeviceScope> devices;
  final int generation;
}

/// Owns the lifetime of the simulated devices: starts them, and resets the
/// whole demo (wipes both devices and the server, then re-seeds the five
/// mock notes).
///
/// This is part of the demo shell (the composition root), not of the notes
/// feature.
class DemoSessionCubit extends Cubit<DemoSessionState> {
  DemoSessionCubit(this._root) : super(const DemoSessionLoading());

  final GetIt _root;
  List<DeviceScope> _devices = [];
  int _generation = 0;

  /// Starts both devices.
  Future<void> start() async {
    _devices = [
      for (final profile in demoDevices)
        await DeviceScope.create(profile, _root),
    ];
    emit(DemoSessionReady(_devices, ++_generation));
  }

  /// Wipes everything and starts again from the mock data.
  Future<void> reset() async {
    emit(const DemoSessionLoading());
    for (final device in _devices) {
      await device.dispose(wipeData: true);
    }
    final server = _root<MockSyncServer>();
    await server.reset();
    await server.seedIfEmpty(NoteFields.collection, seedNotes());
    await start();
  }

  @override
  Future<void> close() async {
    for (final device in _devices) {
      await device.dispose();
    }
    return super.close();
  }
}
