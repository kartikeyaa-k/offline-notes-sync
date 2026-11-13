import 'dart:async';

import '../connectivity/connectivity_service.dart';
import '../sync/remote/sync_remote_gateway.dart';
import 'mock_sync_server.dart';

/// A [SyncRemoteGateway] that talks to an in-process [MockSyncServer] while
/// simulating a real network:
///
/// * **Offline**: every call throws [NetworkException] when this device's
///   [ConnectivityService] is offline.
/// * **Latency**: each request waits [latency] before reaching the server and
///   again before the response arrives.
/// * **Dropped responses**: the device can go offline *after* the server
///   applied a push but *before* the response arrives (or a test can call
///   [dropNextResponse]). The device then retries with the same `opId`, and
///   the server's idempotency check makes the retry safe.
/// * **Change notifications** are only delivered while online, like a
///   WebSocket that disconnects with the network.
class MockRemoteGateway implements SyncRemoteGateway {
  MockRemoteGateway({
    required this._server,
    required this.collection,
    required this._connectivity,
    this.latency = const Duration(milliseconds: 350),
  });

  final MockSyncServer _server;
  final ConnectivityService _connectivity;

  /// The collection this gateway reads and writes (for example `notes`).
  final String collection;

  /// Simulated one-way network latency.
  final Duration latency;

  bool _dropNextResponse = false;

  /// Makes the next push reach the server but lose its response (for tests).
  void dropNextResponse() => _dropNextResponse = true;

  @override
  Future<PushResponse> push(PushRequest request) async {
    await _travel();
    final response = await _server.handlePush(collection, request);
    if (_dropNextResponse) {
      _dropNextResponse = false;
      throw const NetworkException(
        'Connection dropped before the response arrived',
      );
    }
    await _travel();
    return response;
  }

  @override
  Future<PullResponse> pull({required int since, int limit = 100}) async {
    await _travel();
    final response = await _server.handlePull(
      collection,
      since: since,
      limit: limit,
    );
    await _travel();
    return response;
  }

  @override
  Stream<ServerChange> get serverChanges => _server.changes
      .where((event) => event.$1 == collection && _connectivity.isOnline)
      .map((event) => event.$2);

  /// One network hop: fails if offline before or after the delay.
  Future<void> _travel() async {
    _ensureOnline();
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    _ensureOnline();
  }

  void _ensureOnline() {
    if (!_connectivity.isOnline) throw const NetworkException();
  }
}
