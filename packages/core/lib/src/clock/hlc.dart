/// A Hybrid Logical Clock (HLC) timestamp.
///
/// An HLC timestamp combines:
/// * [millis]: wall-clock time in milliseconds since epoch (Coordinated
///   Universal Time, UTC),
/// * [counter]: a logical counter that orders events in the same millisecond
///   (or when the wall clock goes backwards),
/// * [nodeId]: the device that produced it, which breaks the final tie.
///
/// Together these give a **total order** over every edit made on every
/// device. That ordering is what decides "who wins" in a conflict: the edit
/// with the greater [Hlc] wins (see `LwwMerger`).
///
/// Why not plain `DateTime.now()`?
/// * Two edits in the same millisecond would tie. The counter and node id
///   break the tie deterministically.
/// * If a device's clock jumps backwards, its new edits would sort *before*
///   its own earlier edits. An HLC never goes backwards.
/// * When a device receives a remote edit, its clock moves forward past it
///   (`HlcClock.observe`), so anything it edits afterwards is ordered after
///   what it has already seen (causality is preserved).
class Hlc implements Comparable<Hlc> {
  const Hlc({
    required this.millis,
    required this.counter,
    required this.nodeId,
  });

  /// The smallest timestamp for [nodeId]. Used as a seed.
  const Hlc.zero(this.nodeId) : millis = 0, counter = 0;

  /// Parses the output of [pack].
  factory Hlc.parse(String packed) {
    final first = packed.indexOf(':');
    final second = packed.indexOf(':', first + 1);
    if (first <= 0 || second <= first) {
      throw FormatException('Invalid HLC string', packed);
    }
    return Hlc(
      millis: int.parse(packed.substring(0, first)),
      counter: int.parse(packed.substring(first + 1, second), radix: 36),
      nodeId: packed.substring(second + 1),
    );
  }

  /// Physical component, in milliseconds since epoch (UTC).
  final int millis;

  /// Logical component that orders events within the same [millis].
  final int counter;

  /// Identifier of the device (node) that generated this timestamp.
  final String nodeId;

  /// The physical component as a [DateTime] (UTC).
  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

  /// Order: [millis], then [counter], then [nodeId]. Never returns 0 for
  /// timestamps from different nodes, so there are no ties.
  @override
  int compareTo(Hlc other) {
    final byMillis = millis.compareTo(other.millis);
    if (byMillis != 0) return byMillis;
    final byCounter = counter.compareTo(other.counter);
    if (byCounter != 0) return byCounter;
    return nodeId.compareTo(other.nodeId);
  }

  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator >=(Hlc other) => compareTo(other) >= 0;
  bool operator <(Hlc other) => compareTo(other) < 0;
  bool operator <=(Hlc other) => compareTo(other) <= 0;

  /// Serialises to a string that sorts the same way as [compareTo] for the
  /// same node (millis zero-padded, counter in base 36).
  String pack() =>
      '${millis.toString().padLeft(15, '0')}:'
      '${counter.toRadixString(36).padLeft(5, '0')}:$nodeId';

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.millis == millis &&
      other.counter == counter &&
      other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(millis, counter, nodeId);

  @override
  String toString() => pack();
}
