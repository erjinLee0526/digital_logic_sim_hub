import 'dart:ui';

/// A wire connecting two pins on the circuit.
/// Wires are bidirectional for signal propagation purposes.
class Wire {
  final String id;

  /// The pin ID (format: "chipId_pinNumber") of one endpoint.
  final String pinIdA;

  /// The pin ID of the other endpoint.
  final String pinIdB;

  /// Wire propagation delay in picoseconds (near-zero for on-screen wires).
  final int propagationDelayPs;

  const Wire({
    required this.id,
    required this.pinIdA,
    required this.pinIdB,
    this.propagationDelayPs = 0,
  });

  /// Checks whether a circuit-coordinate point is near this wire segment.
  /// [pinPositions] maps pinId → absolute position on canvas.
  bool pointNearWire(Offset point, Map<String, Offset> pinPositions,
      {double tolerance = 8.0}) {
    final p1 = pinPositions[pinIdA];
    final p2 = pinPositions[pinIdB];
    if (p1 == null || p2 == null) return false;
    return _distanceToSegment(point, p1, p2) < tolerance;
  }

  /// Returns the other endpoint pin ID given one.
  String? otherEnd(String pinId) {
    if (pinId == pinIdA) return pinIdB;
    if (pinId == pinIdB) return pinIdA;
    return null;
  }

  /// Whether this wire is connected to the given pin.
  bool connectsTo(String pinId) => pinId == pinIdA || pinId == pinIdB;

  /// Finds the shortest distance from a point to a line segment.
  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy);
    final clamped = t.clamp(0.0, 1.0);
    final closest = a + ab * clamped;
    return (p - closest).distance;
  }
}
