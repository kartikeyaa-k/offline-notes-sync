import 'dart:async';

import 'package:core/core.dart';
import 'package:core/mock_server.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Streams the mock server's copy of a collection for the demo's "Server"
/// panel, so you can watch versions and per-field clocks change live.
class ServerInspectorCubit extends Cubit<List<SyncRecord>> {
  ServerInspectorCubit(MockSyncServer server, String collection)
    : super(const []) {
    _subscription = server.watchCollection(collection).listen(emit);
  }

  late final StreamSubscription<List<SyncRecord>> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
