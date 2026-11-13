import 'dart:math' as math;

import 'package:core/src/clock/hlc.dart';

/// Produces monotonically increasing [Hlc] (Hybrid Logical Clock) timestamps
/// for one device.
///
/// * [now] is called for every local edit.
/// * [observe] is called for every remote timestamp the device receives, so
///   later local edits are ordered after everything already seen.
///
/// The clock is in-memory. On start-up the sync engine re-seeds it with the
/// greatest timestamp found in local storage ([seed]), so it stays monotonic
/// across app restarts without an extra write per edit.
class HlcClock {
  HlcClock({required this.nodeId, int Function()? wallClock})
    : _wallClock = wallClock ?? (() => DateTime.now().millisecondsSinceEpoch),
      _last = Hlc.zero(nodeId);

  /// Identifier of this device; stamped into every generated [Hlc].
  final String nodeId;

  final int Function() _wallClock;
  Hlc _last;

  /// The most recently issued or observed timestamp.
  Hlc get last => _last;

  /// Returns a new timestamp strictly greater than any issued or observed.
  Hlc now() {
    final wall = _wallClock();
    _last = wall > _last.millis
        ? Hlc(millis: wall, counter: 0, nodeId: nodeId)
        : Hlc(millis: _last.millis, counter: _last.counter + 1, nodeId: nodeId);
    return _last;
  }

  /// Merges a timestamp received from another device (standard HLC "receive"
  /// rule). After this call, [now] is guaranteed to return something greater
  /// than [remote].
  void observe(Hlc remote) {
    final wall = _wallClock();
    final maxMillis = math.max(wall, math.max(_last.millis, remote.millis));
    final int counter;
    if (maxMillis == _last.millis && maxMillis == remote.millis) {
      counter = math.max(_last.counter, remote.counter) + 1;
    } else if (maxMillis == _last.millis) {
      counter = _last.counter + 1;
    } else if (maxMillis == remote.millis) {
      counter = remote.counter + 1;
    } else {
      counter = 0;
    }
    _last = Hlc(millis: maxMillis, counter: counter, nodeId: nodeId);
  }

  /// Fast-forwards the clock to at least [timestamp] (used at start-up).
  void seed(Hlc timestamp) {
    if (timestamp.millis > _last.millis ||
        (timestamp.millis == _last.millis &&
            timestamp.counter > _last.counter)) {
      _last = Hlc(
        millis: timestamp.millis,
        counter: timestamp.counter,
        nodeId: nodeId,
      );
    }
  }
}
