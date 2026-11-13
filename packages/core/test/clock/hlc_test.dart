// Tests for Hlc (Hybrid Logical Clock) ordering and HlcClock behaviour.
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hlc', () {
    test('orders by millis, then counter, then node id', () {
      const a = Hlc(millis: 1, counter: 5, nodeId: 'z');
      const b = Hlc(millis: 2, counter: 0, nodeId: 'a');
      const c = Hlc(millis: 2, counter: 1, nodeId: 'a');
      const d = Hlc(millis: 2, counter: 1, nodeId: 'b');
      expect([d, c, b, a]..sort(), [a, b, c, d]);
    });

    test('pack/parse round-trips', () {
      const hlc = Hlc(millis: 1731500000000, counter: 42, nodeId: 'device-a');
      expect(Hlc.parse(hlc.pack()), hlc);
    });
  });

  group('HlcClock', () {
    test('is monotonic even if the wall clock goes backwards', () {
      var wall = 1000;
      final clock = HlcClock(nodeId: 'a', wallClock: () => wall);
      final first = clock.now();
      wall = 500; // clock jumped back
      final second = clock.now();
      expect(second > first, isTrue);
      expect(second.millis, 1000);
      expect(second.counter, 1);
    });

    test('observe moves the clock past a remote timestamp', () {
      final clock = HlcClock(nodeId: 'a', wallClock: () => 1000);
      clock.observe(const Hlc(millis: 5000, counter: 3, nodeId: 'b'));
      final next = clock.now();
      expect(next > const Hlc(millis: 5000, counter: 3, nodeId: 'b'), isTrue);
    });
  });
}
