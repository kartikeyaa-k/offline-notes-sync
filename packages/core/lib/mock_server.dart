/// An in-process mock of the sync backend, for demos and tests.
///
/// Kept in a separate library so production code never imports it by
/// accident: replace `MockRemoteGateway` with a real `SyncRemoteGateway`
/// (REST, Representational State Transfer, or gRPC client) and nothing else
/// changes.
library;

export 'src/mock_server/mock_remote_gateway.dart';
export 'src/mock_server/mock_sync_server.dart';
