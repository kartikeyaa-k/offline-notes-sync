import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// State of one simulated device's network.
class DeviceNetworkState {
  const DeviceNetworkState({required this.switchOn, required this.isOnline});

  /// The demo's Wi-Fi switch.
  final bool switchOn;

  /// Effective connectivity (switch on and real network available).
  final bool isOnline;
}

/// Drives the demo's per-device network switch.
class DeviceNetworkCubit extends Cubit<DeviceNetworkState> {
  DeviceNetworkCubit(this._network)
    : super(
        DeviceNetworkState(
          switchOn: _network.networkEnabled,
          isOnline: _network.isOnline,
        ),
      ) {
    _subscription = _network.onStatusChange.listen((_) => _refresh());
  }

  final SimulatedConnectivityService _network;
  late final StreamSubscription<bool> _subscription;

  /// Turns the simulated network on or off.
  void setNetwork({required bool on}) {
    _network.setNetworkEnabled(enabled: on);
    _refresh();
  }

  void _refresh() => emit(
    DeviceNetworkState(
      switchOn: _network.networkEnabled,
      isOnline: _network.isOnline,
    ),
  );

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
