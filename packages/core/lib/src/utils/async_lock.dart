import 'dart:async';

/// A minimal asynchronous mutex.
///
/// Dart runs on one thread, but an `async` read-modify-write can still
/// interleave with another at every `await`. Wrapping those sections in
/// [synchronized] makes them run one after another, in call order.
class AsyncLock {
  Future<void> _tail = Future.value();

  /// Runs [action] after every previously queued action has finished.
  Future<T> synchronized<T>(FutureOr<T> Function() action) {
    final result = _tail.then((_) => action());
    // Keep the queue going even if this action fails.
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}
