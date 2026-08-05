import 'dart:ui';
import '../models/chip_instance.dart';
import '../models/circuit.dart';
import '../models/wire.dart';
import 'circuit_painter.dart';

/// The type of element that was hit.
enum HitTarget {
  pin,
  chipBody,
  wire,
  canvasBackground,
}

/// Result of a hit-test against the circuit canvas.
class HitTestResult {
  final HitTarget target;
  final String? chipId;
  final int? pinNumber;
  final String? pinId; // "chipId_pinNumber"
  final String? wireId;
  final Offset circuitPoint;

  const HitTestResult({
    required this.target,
    this.chipId,
    this.pinNumber,
    this.pinId,
    this.wireId,
    required this.circuitPoint,
  });

  /// Shorthand for a canvas-background hit.
  factory HitTestResult.background(Offset point) => HitTestResult(
        target: HitTarget.canvasBackground,
        circuitPoint: point,
      );
}

/// Performs hit-testing on the circuit at a point in circuit coordinates.
HitTestResult hitTest(Offset point, Circuit circuit,
    {double pinRadius = 12.0}) {
  // 1. Check pins (smallest hit area, highest priority)
  for (final chip in circuit.chips) {
    final positions = chip.pinAbsolutePositions;
    for (final entry in positions.entries) {
      if ((entry.value - point).distance < pinRadius) {
        return HitTestResult(
          target: HitTarget.pin,
          chipId: chip.id,
          pinNumber: entry.key,
          pinId: chip.pinId(entry.key),
          circuitPoint: point,
        );
      }
    }
  }

  // 2. Check chip bodies
  for (final chip in circuit.chips) {
    if (chip.rect.contains(point)) {
      return HitTestResult(
        target: HitTarget.chipBody,
        chipId: chip.id,
        circuitPoint: point,
      );
    }
  }

  // 3. Check wires (using orthogonal path segments)
  final pinPositions = circuit.allPinPositions;

  // Group wires by pin to detect multi-wire pins (branch points)
  final wiresForPin = <String, List<Wire>>{};
  for (final wire in circuit.wires) {
    wiresForPin.putIfAbsent(wire.pinIdA, () => []).add(wire);
    wiresForPin.putIfAbsent(wire.pinIdB, () => []).add(wire);
  }

  // Pre-compute anchor vertical segments for multi-wire pins
  final anchorVSegs = <String, VSegment?>{};
  for (final entry in wiresForPin.entries) {
    if (entry.value.length < 2) continue;
    final anchorWire = entry.value.first;
    final aPos = pinPositions[anchorWire.pinIdA];
    final bPos = pinPositions[anchorWire.pinIdB];
    if (aPos == null || bPos == null) continue;

    final aChip = _chipForPinId(anchorWire.pinIdA, circuit);
    final bChip = _chipForPinId(anchorWire.pinIdB, circuit);
    final anchorPath = computeWireRoute(aPos, bPos, aChip, bChip, circuit.chips);
    anchorVSegs[entry.key] = findVerticalSegment(anchorPath);
  }

  for (final wire in circuit.wires) {
    final p1 = pinPositions[wire.pinIdA];
    final p2 = pinPositions[wire.pinIdB];
    if (p1 == null || p2 == null) continue;

    final chip1 = _chipForPinId(wire.pinIdA, circuit);
    final chip2 = _chipForPinId(wire.pinIdB, circuit);

    // If this is the second+ wire at a pin, choose branch point on
    // the anchor's vertical segment based on target Y.
    Offset? overrideStart;
    Offset? overrideEnd;

    final pinAWires = wiresForPin[wire.pinIdA] ?? [];
    if (pinAWires.length >= 2 && pinAWires.first.id != wire.id) {
      final seg = anchorVSegs[wire.pinIdA];
      if (seg != null) {
        overrideStart = branchPointOnSegment(seg, p2.dy);
      } else {
        overrideStart = pinBranchOffset(wire.pinIdA, p1, circuit);
      }
    }

    final pinBWires = wiresForPin[wire.pinIdB] ?? [];
    if (pinBWires.length >= 2 && pinBWires.first.id != wire.id) {
      final seg = anchorVSegs[wire.pinIdB];
      if (seg != null) {
        overrideEnd = branchPointOnSegment(seg, p1.dy);
      } else {
        overrideEnd = pinBranchOffset(wire.pinIdB, p2, circuit);
      }
    }

    final path = computeWireRoute(p1, p2, chip1, chip2, circuit.chips,
        overrideStart: overrideStart, overrideEnd: overrideEnd);

    // Check distance to each segment of the orthogonal path
    if (_pointNearPath(point, path, tolerance: 10.0)) {
      return HitTestResult(
        target: HitTarget.wire,
        wireId: wire.id,
        circuitPoint: point,
      );
    }
  }

  // 4. Nothing hit
  return HitTestResult.background(point);
}

// ── Shared helpers ──

ChipInstance? _chipForPinId(String pinId, Circuit circuit) {
  for (final chip in circuit.chips) {
    if (pinId.startsWith('${chip.id}_')) return chip;
  }
  return null;
}

/// Checks if [point] is within [tolerance] of any segment in the path.
bool _pointNearPath(Offset point, List<Offset> path,
    {double tolerance = 8.0}) {
  for (int i = 0; i < path.length - 1; i++) {
    if (_distanceToSegment(point, path[i], path[i + 1]) < tolerance) {
      return true;
    }
  }
  return false;
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final ap = p - a;
  final t =
      (ap.dx * ab.dx + ap.dy * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy);
  final clamped = t.clamp(0.0, 1.0);
  final closest = a + ab * clamped;
  return (p - closest).distance;
}
