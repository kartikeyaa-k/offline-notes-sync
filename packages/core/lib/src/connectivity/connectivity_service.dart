import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Tells the sync engine whether the backend is worth trying.
///
/// The engine never *trusts* this blindly: a push or pull can still fail
/// with a `NetworkException` while "online", and that is handled as a
/// retryable failure. Connectivity is a *trigger* ("we just came back
/// online, sync now"), not a guarantee.
abstract interface class ConnectivityService {
  /// Current best guess.
  bool get isOnline;

  /// Emits whenever [isOnline] changes (distinct values only).
  Stream<bool> get onStatusChange;

  /// Starts listening to the platform.
  Future<void> start();

  /// Stops listening.
  Future<void> dispose();
}

/// Real connectivity for a physical device.
///
/// Uses `connectivity_plus` for the instant "radio off" signal (aeroplane
/// mode, Wi-Fi dropped) and `internet_connection_checker_plus` to confirm
/// there is real internet access (a Wi-Fi with a captive portal is
/// "connected" but not online).
class DeviceConnectivityService implements ConnectivityService {
  DeviceConnectivityService({
    Connectivity? connectivity,
    InternetConnection? internet,
  }) : _connectivity = connectivity ?? Connectivity(),
       _internet = internet ?? InternetConnection();

  final Connectivity _connectivity;
  final InternetConnection _internet;
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _radioSub;
  StreamSubscription<InternetStatus>? _internetSub;
  bool _isOnline = false;

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  @override
  Future<void> start() async {
    _set(await _internet.hasInternetAccess);
    _radioSub = _connectivity.onConnectivityChanged.listen((results) async {
      if (results.every((r) => r == ConnectivityResult.none)) {
        _set(false);
      } else {
        _set(await _internet.hasInternetAccess);
      }
    });
    _internetSub = _internet.onStatusChange.listen(
      (status) => _set(status == InternetStatus.connected),
    );
  }

  void _set(bool value) {
    if (value == _isOnline) return;
    _isOnline = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  @override
  Future<void> dispose() async {
    await _radioSub?.cancel();
    await _internetSub?.cancel();
    await _controller.close();
  }
}

/// A connectivity service with a manual "network" switch, layered on an
/// optional real [upstream].
///
/// The demo runs two simulated devices in one app. Each gets its own
/// [SimulatedConnectivityService], so one can be "offline" while the other is
/// online. Online means: the switch is on **and** the upstream (real device
/// network) is online.
///
/// The [upstream] is shared and owned by the caller; [dispose] does not
/// dispose it.
class SimulatedConnectivityService implements ConnectivityService {
  SimulatedConnectivityService({this.upstream, this._networkEnabled = true});

  /// Optional real connectivity to combine with the switch.
  final ConnectivityService? upstream;

  bool _networkEnabled;
  bool _lastEmitted = false;
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<bool>? _upstreamSub;

  /// The manual switch.
  bool get networkEnabled => _networkEnabled;

  /// Flips the manual switch (the demo's "Wi-Fi" toggle).
  void setNetworkEnabled(bool enabled) {
    _networkEnabled = enabled;
    _emitIfChanged();
  }

  @override
  bool get isOnline => _networkEnabled && (upstream?.isOnline ?? true);

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  @override
  Future<void> start() async {
    _lastEmitted = isOnline;
    _upstreamSub = upstream?.onStatusChange.listen((_) => _emitIfChanged());
  }

  void _emitIfChanged() {
    final now = isOnline;
    if (now == _lastEmitted) return;
    _lastEmitted = now;
    if (!_controller.isClosed) _controller.add(now);
  }

  @override
  Future<void> dispose() async {
    await _upstreamSub?.cancel();
    await _controller.close();
  }
}
