import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/chip_instance.dart';
import '../models/circuit.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';
import '../models/wire.dart';
import '../theme/dark_theme.dart';

/// Computes the branch point offset for a pin — where additional wires
/// should fan out from, along the pin's exit direction.
/// [pinPos] must be the absolute canvas position of the pin.
///
/// This is a simple fixed-offset fallback. Prefer [computeWireBranchPoint]
/// or the per‑wire branch-point calculation that uses the anchor wire's
/// vertical segment and the target pin's Y position.
Offset pinBranchOffset(String pinId, Offset pinPos, Circuit circuit) {
  ChipInstance? chip;
  for (final c in circuit.chips) {
    if (pinId.startsWith('${c.id}_')) {
      chip = c;
      break;
    }
  }
  const branchDistance = 25.0;
  final dir = (chip != null && pinPos.dx < chip.rect.center.dx) ? -1.0 : 1.0;
  return Offset(pinPos.dx + dir * branchDistance, pinPos.dy);
}

// ═══════════════════════════════════════════════════════════════════
// Branch-point computation on vertical segment
// ═══════════════════════════════════════════════════════════════════

/// A vertical run of a wire path: all points share the same X.
class VSegment {
  final double x;
  final double yMin; // top
  final double yMax; // bottom
  const VSegment({required this.x, required this.yMin, required this.yMax});
}

/// Finds the longest vertical segment in [path].
VSegment? findVerticalSegment(List<Offset> path) {
  if (path.length < 2) return null;

  double? bestX;
  double bestY1 = 0, bestY2 = 0;
  double bestLen = 0;

  for (int i = 0; i < path.length - 1; i++) {
    if ((path[i].dx - path[i + 1].dx).abs() < 0.5) {
      final y1 = min(path[i].dy, path[i + 1].dy);
      final y2 = max(path[i].dy, path[i + 1].dy);
      final len = y2 - y1;
      // Merge consecutive vertical segments at the same X
      if (bestX != null && (path[i].dx - bestX).abs() < 0.5) {
        bestY1 = min(bestY1, y1);
        bestY2 = max(bestY2, y2);
        bestLen = bestY2 - bestY1;
      } else if (len > bestLen) {
        bestX = path[i].dx;
        bestY1 = y1;
        bestY2 = y2;
        bestLen = len;
      }
    }
  }

  if (bestX == null) return null;
  return VSegment(x: bestX, yMin: bestY1, yMax: bestY2);
}

/// Picks the optimal branch point on the vertical segment for a wire
/// whose target is at [targetY].
///
/// - target above segment  →  top corner
/// - target below segment  →  bottom corner
/// - target inside segment →  point on segment at targetY (direct horizontal)
Offset branchPointOnSegment(VSegment seg, double targetY) {
  if (targetY < seg.yMin) return Offset(seg.x, seg.yMin);
  if (targetY > seg.yMax) return Offset(seg.x, seg.yMax);
  return Offset(seg.x, targetY);
}

/// Returns the branch point for a pin that already has wires connected.
///
/// Uses the anchor wire's vertical segment and [targetY] to pick the
/// optimal branch point.  Falls back to [pinBranchOffset] when there
/// is no useful vertical segment.
///
/// Set [requireMultipleWires] to false for ghost‑wire preview (while
/// the second connection is being created and the pin has only 1 wire).
Offset? computeWireBranchPoint(String pinId, Circuit circuit,
    {bool requireMultipleWires = true, double? targetY}) {
  // Count and find the first (anchor) wire
  int count = 0;
  Wire? anchorWire;
  for (final w in circuit.wires) {
    if (w.connectsTo(pinId)) {
      count++;
      anchorWire ??= w;
    }
  }
  if (count == 0) return null;
  if (requireMultipleWires && count < 2) return null;

  final pinPositions = circuit.allPinPositions;
  final pinPos = pinPositions[pinId];
  if (pinPos == null) return null;

  final p1 = pinPositions[anchorWire!.pinIdA];
  final p2 = pinPositions[anchorWire.pinIdB];
  if (p1 == null || p2 == null) return null;

  ChipInstance? chip1, chip2;
  for (final c in circuit.chips) {
    if (anchorWire.pinIdA.startsWith('${c.id}_')) chip1 = c;
    if (anchorWire.pinIdB.startsWith('${c.id}_')) chip2 = c;
  }

  final path = computeWireRoute(p1, p2, chip1, chip2, circuit.chips);
  final vSeg = findVerticalSegment(path);

  if (vSeg != null && targetY != null) {
    return branchPointOnSegment(vSeg, targetY);
  }

  // Fallback: corner nearest the pin
  if (path.length >= 2) {
    if (anchorWire.pinIdA == pinId) return path[1];
    return path[path.length - 2];
  }

  return pinBranchOffset(pinId, pinPos, circuit);
}

/// Returns -1 for pins on the left half of their chip, +1 for right.
double exitDirection(Offset pinPos, ChipInstance? chip) {
  if (chip == null) return 1.0;
  return pinPos.dx < chip.rect.center.dx ? -1.0 : 1.0;
}

/// Generates candidate X positions for the vertical routing column.
List<double> _candidateColumns(
    Offset p1, Offset p2, double dir1, double dir2, double exitMargin) {
  final candidates = <double>[];
  if (dir1 == dir2) {
    final base = (dir1 > 0)
        ? max(p1.dx, p2.dx) + exitMargin
        : min(p1.dx, p2.dx) - exitMargin;
    candidates.add(base);
    for (int i = 1; i < 50; i++) {
      candidates.add(base + dir1 * i * 20);
    }
  } else {
    final mid = (p1.dx + p2.dx) / 2;
    candidates.add(mid);
    for (int i = 1; i < 50; i++) {
      candidates.add(mid + i * 20);
      candidates.add(mid - i * 20);
    }
  }
  return candidates;
}

/// Returns true if the axis-aligned segment [a]→[b] intersects any
/// chip body rect (optionally skipping [skipChipId]).
bool _segHitsChip(Offset a, Offset b, List<Rect> obstacleRects,
    List<String> chipIds, String? skipChipId) {
  if ((a - b).distance < 0.5) return false;

  final isHorizontal = (a.dy - b.dy).abs() < 0.5;
  final isVertical = (a.dx - b.dx).abs() < 0.5;
  if (!isHorizontal && !isVertical) return false;

  final segMinX = min(a.dx, b.dx);
  final segMaxX = max(a.dx, b.dx);
  final segMinY = min(a.dy, b.dy);
  final segMaxY = max(a.dy, b.dy);

  for (int i = 0; i < obstacleRects.length; i++) {
    if (chipIds[i] == skipChipId) continue;
    final r = obstacleRects[i];
    if (isHorizontal) {
      if (a.dy > r.top &&
          a.dy < r.bottom &&
          segMaxX > r.left &&
          segMinX < r.right) {
        return true;
      }
    } else {
      if (a.dx > r.left &&
          a.dx < r.right &&
          segMaxY > r.top &&
          segMinY < r.bottom) {
        return true;
      }
    }
  }
  return false;
}

/// Phase-2 fallback: route around obstacles by going above/below them.
///
/// All chips are treated as obstacles — no chip is skipped, because this
/// function computes a path that goes *outside* the cluster of all chips.
List<Offset> _routeAround(Offset p1, Offset p2, double dir1, double dir2,
    double exitMargin, List<Rect> obstacleRects, List<String> chipIds) {
  const cornerMargin = 15.0;

  final ex1 = p1.dx + dir1 * exitMargin;
  final ex2 = p2.dx + dir2 * exitMargin;

  // Use the exit-point X range (not the pin X range) because the wire
  // actually spans from exit1 to exit2 horizontally.
  final routeMinX = min(ex1, ex2);
  final routeMaxX = max(ex1, ex2);
  final yMin = min(p1.dy, p2.dy);
  final yMax = max(p1.dy, p2.dy);

  double highestTop = double.infinity;
  double lowestBottom = double.negativeInfinity;
  bool hasObstacle = false;
  for (int i = 0; i < obstacleRects.length; i++) {
    final r = obstacleRects[i];
    if (r.bottom > yMin && r.top < yMax) {
      if (r.right > routeMinX && r.left < routeMaxX) {
        hasObstacle = true;
        highestTop = min(highestTop, r.top);
        lowestBottom = max(lowestBottom, r.bottom);
      }
    }
  }

  // Try the direct stair-step path first, but validate every segment
  // against *all* chips (no skipping — we must not enter any chip body).
  if (!hasObstacle) {
    final mx = (ex1 + ex2) / 2;
    final candidate = <Offset>[
      p1,
      Offset(ex1, p1.dy),
      Offset(mx, p1.dy),
      Offset(mx, p2.dy),
      Offset(ex2, p2.dy),
      p2,
    ];
    // Verify every segment against every chip
    bool ok = true;
    for (int i = 0; ok && i < candidate.length - 1; i++) {
      if (_segHitsChip(
          candidate[i], candidate[i + 1], obstacleRects, chipIds, null)) {
        ok = false;
      }
    }
    if (ok) return candidate;
    // Fall through: a chip blocks the direct path after all, so re-detect
    // obstacles across the full Y range (including chips above/below the
    // pin band that the vertical segment at mx would intersect).
    hasObstacle = true;
    for (final r in obstacleRects) {
      if (r.right > routeMinX && r.left < routeMaxX) {
        highestTop = min(highestTop, r.top);
        lowestBottom = max(lowestBottom, r.bottom);
      }
    }
  }

  final goAbove = (p1.dy - highestTop).abs() + (p2.dy - highestTop).abs() <
      (p1.dy - lowestBottom).abs() + (p2.dy - lowestBottom).abs();
  final clearanceY =
      goAbove ? highestTop - cornerMargin : lowestBottom + cornerMargin;

  double minAllX = double.infinity;
  double maxAllX = double.negativeInfinity;
  for (final r in obstacleRects) {
    minAllX = min(minAllX, r.left);
    maxAllX = max(maxAllX, r.right);
  }

  double outerX;
  if (dir1 == dir2) {
    outerX = (dir1 < 0) ? minAllX - exitMargin : maxAllX + exitMargin;
  } else {
    outerX = (dir1 < 0)
        ? min(p1.dx, minAllX) - exitMargin
        : max(p1.dx, maxAllX) + exitMargin;
  }

  return [
    p1,
    Offset(ex1, p1.dy),
    Offset(outerX, p1.dy),
    Offset(outerX, clearanceY),
    Offset(ex2, clearanceY),
    Offset(ex2, p2.dy),
    p2,
  ];
}

/// Computes the orthogonal (Manhattan) path between two points, avoiding
/// chip bodies.  This is the standalone routing function shared by the
/// painter, hit‑test, and junction‑point computation.
List<Offset> computeWireRoute(Offset p1, Offset p2, ChipInstance? chip1,
    ChipInstance? chip2, List<ChipInstance> allChips,
    {Offset? overrideStart, Offset? overrideEnd}) {
  const exitMargin = 25.0;

  final start = overrideStart ?? p1;
  final end = overrideEnd ?? p2;
  final startSkipId = overrideStart != null ? null : chip1?.id;
  final endSkipId = overrideEnd != null ? null : chip2?.id;

  final obstacleRects = <Rect>[];
  final chipIds = <String>[];
  for (final chip in allChips) {
    final r = chip.rect;
    obstacleRects
        .add(Rect.fromLTRB(r.left - 8, r.top - 8, r.right + 8, r.bottom + 8));
    chipIds.add(chip.id);
  }

  // ── Direct L‑shaped paths (only for junction / branch points) ────
  // When one endpoint is already outside all chip bodies (a junction
  // on an existing wire), a simple 3‑point L‑shaped path avoids the
  // column‑based routing's mandatory exit margin, which would otherwise
  // force the wire to go right back toward the chip and then detour.
  //
  // For normal pin‑to‑pin connections both endpoints are on chip edges,
  // so the horizontal‑first segments would cross the chip body and are
  // correctly rejected by the chip‑collision check below.
  if (overrideStart != null || overrideEnd != null) {
    // Helper: check whether an end-segment corner is on the correct side
    // of the target pin.  A left-side pin must be entered from the left,
    // a right-side pin from the right, otherwise the wire would cross
    // through the chip body.
    bool entersFromCorrectSide(Offset corner) {
      if (endSkipId == null || overrideEnd != null || chip2 == null) {
        return true; // no pin to enter, or already a junction
      }
      final pinOnLeft = end.dx < chip2.rect.center.dx;
      return pinOnLeft ? corner.dx <= end.dx : corner.dx >= end.dx;
    }

    // Path A: vertical first  →  ─┐
    final cornerA = Offset(start.dx, end.dy);
    final skipA2 = entersFromCorrectSide(cornerA) ? endSkipId : null;
    if (!_segHitsChip(start, cornerA, obstacleRects, chipIds, startSkipId) &&
        !_segHitsChip(cornerA, end, obstacleRects, chipIds, skipA2)) {
      return [start, cornerA, end];
    }

    // Path B: horizontal first  →  └─
    final cornerB = Offset(end.dx, start.dy);
    final skipB2 = entersFromCorrectSide(cornerB) ? endSkipId : null;
    if (!_segHitsChip(start, cornerB, obstacleRects, chipIds, startSkipId) &&
        !_segHitsChip(cornerB, end, obstacleRects, chipIds, skipB2)) {
      return [start, cornerB, end];
    }
  }

  // ── Phase 1: column‑based stair‑step ────────────────────────────
  // When overrideStart/overrideEnd is set, the point is already outside
  // the chip body (on an anchor wire's vertical segment). We still use
  // chip1/chip2 to determine the correct exit direction — a branch point
  // left of the chip should exit left (-1), not default to right (+1).
  final dir1 = exitDirection(start, chip1);
  final dir2 = exitDirection(end, chip2);

  final candidates = _candidateColumns(start, end, dir1, dir2, exitMargin);

  for (final midX in candidates) {
    final exit1X = (dir1 > 0)
        ? max(start.dx + exitMargin, midX)
        : min(start.dx - exitMargin, midX);
    final exit2X = (dir2 > 0)
        ? max(end.dx + exitMargin, midX)
        : min(end.dx - exitMargin, midX);

    final exit1 = Offset(exit1X, start.dy);
    final exit2 = Offset(exit2X, end.dy);
    final corner1 = Offset(midX, start.dy);
    final corner2 = Offset(midX, end.dy);

    if (!_segHitsChip(start, exit1, obstacleRects, chipIds, startSkipId) &&
        !_segHitsChip(exit1, corner1, obstacleRects, chipIds, null) &&
        !_segHitsChip(corner1, corner2, obstacleRects, chipIds, null) &&
        !_segHitsChip(corner2, exit2, obstacleRects, chipIds, null) &&
        !_segHitsChip(exit2, end, obstacleRects, chipIds, endSkipId)) {
      return [start, exit1, corner1, corner2, exit2, end];
    }
  }

  // ── Phase 2: route around obstacles via top/bottom ──────────────
  return _routeAround(
      start, end, dir1, dir2, exitMargin, obstacleRects, chipIds);
}

/// Returns the branch point for a pin that already has wires connected.
/// CustomPainter that renders the entire circuit canvas.
class CircuitPainter extends CustomPainter {
  final Circuit circuit;
  final String? selectedPinId;
  final String? selectedChipId;
  final String? selectedWireId;
  final Offset? ghostWireStart; // circuit-coordinate start of ghost wire
  final Offset? ghostWireEnd; // circuit-coordinate end of ghost wire

  CircuitPainter({
    required this.circuit,
    this.selectedPinId,
    this.selectedChipId,
    this.selectedWireId,
    this.ghostWireStart,
    this.ghostWireEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppTheme.canvasBg,
    );

    // Draw grid
    _drawGrid(canvas, size);

    // Draw wires
    _drawWires(canvas);

    // Draw ghost wire
    if (ghostWireStart != null && ghostWireEnd != null) {
      _drawGhostWire(canvas);
    }

    // Draw chips
    for (final chip in circuit.chips) {
      _drawChip(canvas, chip);
    }
  }

  @override
  bool shouldRepaint(covariant CircuitPainter oldDelegate) {
    return circuit != oldDelegate.circuit ||
        selectedPinId != oldDelegate.selectedPinId ||
        selectedChipId != oldDelegate.selectedChipId ||
        selectedWireId != oldDelegate.selectedWireId ||
        ghostWireStart != oldDelegate.ghostWireStart ||
        ghostWireEnd != oldDelegate.ghostWireEnd;
  }

  // ---- Grid ----

  void _drawGrid(Canvas canvas, Size size) {
    const spacing = 20.0;
    final paint = Paint()
      ..color = AppTheme.gridDot
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  // ---- Wires (orthogonal routing) ----

  void _drawWires(Canvas canvas) {
    final pinPositions = circuit.allPinPositions;

    // Group wires by pin to detect multi-wire pins that need branching
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

      final aChip = _chipForPinId(anchorWire.pinIdA);
      final bChip = _chipForPinId(anchorWire.pinIdB);
      final anchorPath = _computeOrthogonalPath(aPos, bPos, aChip, bChip);
      anchorVSegs[entry.key] = findVerticalSegment(anchorPath);
    }

    // Collect branch-point positions for drawing junction dots
    final branchDots = <String, Offset>{}; // pinId → branch-dot position

    for (final wire in circuit.wires) {
      final p1 = pinPositions[wire.pinIdA];
      final p2 = pinPositions[wire.pinIdB];
      if (p1 == null || p2 == null) continue;

      final chip1 = _chipForPinId(wire.pinIdA);
      final chip2 = _chipForPinId(wire.pinIdB);

      Offset? overrideStart;
      Offset? overrideEnd;

      // For second+ wires at a pin, choose the branch point on the
      // anchor's vertical segment based on where the target is.
      final pinAWires = wiresForPin[wire.pinIdA] ?? [];
      if (pinAWires.length >= 2 && pinAWires.first.id != wire.id) {
        final seg = anchorVSegs[wire.pinIdA];
        if (seg != null) {
          overrideStart = branchPointOnSegment(seg, p2.dy);
        } else {
          overrideStart = pinBranchOffset(wire.pinIdA, p1, circuit);
        }
        // Record branch dot at the source pin's override position
        branchDots[wire.pinIdA] = overrideStart;
      }

      final pinBWires = wiresForPin[wire.pinIdB] ?? [];
      if (pinBWires.length >= 2 && pinBWires.first.id != wire.id) {
        final seg = anchorVSegs[wire.pinIdB];
        if (seg != null) {
          overrideEnd = branchPointOnSegment(seg, p1.dy);
        } else {
          overrideEnd = pinBranchOffset(wire.pinIdB, p2, circuit);
        }
        branchDots[wire.pinIdB] = overrideEnd;
      }

      final path = _computeOrthogonalPath(p1, p2, chip1, chip2,
          overrideStart: overrideStart, overrideEnd: overrideEnd);

      final isSelected = wire.id == selectedWireId;
      final color = isSelected ? AppTheme.wireSelected : _wireColor(wire);

      final paint = Paint()
        ..color = color
        ..strokeWidth = isSelected ? 3.0 : 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final drawPath = _offsetListToPath(path);
      canvas.drawPath(drawPath, paint);
    }

    // Draw junction dots at pins and branch points
    _drawJunctionDots(canvas, pinPositions, wiresForPin, branchDots);
  }

  /// Converts a list of offsets into a continuous path.
  Path _offsetListToPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  /// Finds the chip that owns a given pin ID.
  ChipInstance? _chipForPinId(String pinId) {
    for (final chip in circuit.chips) {
      if (pinId.startsWith('${chip.id}_')) return chip;
    }
    return null;
  }

  List<Offset> _computeOrthogonalPath(
      Offset p1, Offset p2, ChipInstance? chip1, ChipInstance? chip2,
      {Offset? overrideStart, Offset? overrideEnd}) {
    return computeWireRoute(p1, p2, chip1, chip2, circuit.chips,
        overrideStart: overrideStart, overrideEnd: overrideEnd);
  }

  /// Determines color of a wire based on the signal state of connected outputs.
  Color _wireColor(Wire wire) {
    SignalState? state;
    for (final chip in circuit.chips) {
      for (final pin in chip.pinStates.values) {
        final pid = chip.pinId(pin.number);
        if (wire.connectsTo(pid) &&
            pin.direction == PinDirection.output &&
            pin.value.isDriven) {
          state = pin.value;
        }
      }
    }
    return AppTheme.colorForSignal(state ?? SignalState.unknown);
  }

  // ---- Junction dots ----

  /// Draws filled circles at pins that connect 2+ wires and at junction
  /// points where additional wires fan out from the anchor wire's corner.
  void _drawJunctionDots(Canvas canvas, Map<String, Offset> pinPositions,
      Map<String, List<Wire>> wiresForPin, Map<String, Offset> branchDots) {
    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (final entry in wiresForPin.entries) {
      if (entry.value.length < 2) continue;

      final pinId = entry.key;
      final pos = pinPositions[pinId];
      if (pos == null) continue;

      // Determine the signal color from connected output/driven pins
      SignalState? state;
      for (final wire in entry.value) {
        final otherEnd = wire.otherEnd(pinId);
        if (otherEnd == null) continue;
        for (final chip in circuit.chips) {
          for (final pin in chip.pinStates.values) {
            if (chip.pinId(pin.number) == otherEnd &&
                pin.direction == PinDirection.output &&
                pin.value.isDriven) {
              state = pin.value;
            }
          }
        }
      }

      dotPaint.color = AppTheme.colorForSignal(state ?? SignalState.unknown);

      // Junction dot at the pin itself
      canvas.drawCircle(pos, 4.5, dotPaint);
      canvas.drawCircle(
          pos,
          4.5,
          Paint()
            ..color = AppTheme.canvasBg
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);

      // Junction dot at the branch point (on the anchor's vertical segment)
      final bp = branchDots[pinId];
      if (bp != null) {
        canvas.drawCircle(bp, 4.5, dotPaint);
        canvas.drawCircle(
            bp,
            4.5,
            Paint()
              ..color = AppTheme.canvasBg
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0);
      }
    }
  }

  // ---- Ghost Wire ----

  void _drawGhostWire(Canvas canvas) {
    if (ghostWireStart == null || ghostWireEnd == null) return;
    final paint = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Dashed effect
    final path = Path()
      ..moveTo(ghostWireStart!.dx, ghostWireStart!.dy)
      ..lineTo(ghostWireEnd!.dx, ghostWireEnd!.dy);

    canvas.drawPath(
      _dashPath(path, dashLength: 6, gapLength: 4),
      paint,
    );
  }

  Path _dashPath(Path source,
      {required double dashLength, required double gapLength}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len =
            draw ? dashLength.clamp(0, metric.length - distance) : gapLength;
        if (draw) {
          dest.addPath(
              metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  // ---- Chips ----

  void _drawChip(Canvas canvas, ChipInstance chip) {
    final rect = chip.rect;
    final isSelected = chip.id == selectedChipId;

    // Chip body
    final bodyPaint = Paint()
      ..color = AppTheme.chipBody
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isSelected ? AppTheme.chipBorderSelected : AppTheme.chipBorder
      ..strokeWidth = isSelected ? 2.5 : 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rrect, bodyPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Notch indicator (small arc at top center)
    final notchPaint = Paint()
      ..color = AppTheme.chipBorder
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final notchRect = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top + 2),
      width: 20,
      height: 8,
    );
    canvas.drawArc(notchRect, 3.14, 3.14, false, notchPaint);

    if (chip.definition.model == 'INPUT') {
      _drawInputSwitch(canvas, chip, rect);
    } else if (chip.definition.model == 'LED') {
      _drawLED(canvas, chip, rect);
    } else {
      // Model label (centered)
      final modelPainter = TextPainter(
        text: TextSpan(
          text: chip.definition.model,
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      modelPainter.layout();
      modelPainter.paint(
        canvas,
        Offset(
          rect.center.dx - modelPainter.width / 2,
          rect.top + 22,
        ),
      );

      // Description (below model, smaller)
      final descPainter = TextPainter(
        text: TextSpan(
          text: chip.definition.description,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 9,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      descPainter.layout();
      descPainter.paint(
        canvas,
        Offset(
          rect.center.dx - descPainter.width / 2,
          rect.top + 40,
        ),
      );
    }

    // Draw each pin
    _drawPins(canvas, chip);
  }

  void _drawInputSwitch(Canvas canvas, ChipInstance chip, Rect rect) {
    final output = chip.pinStates.values.firstWhere(
      (p) => p.direction == PinDirection.output,
      orElse: () => chip.pinStates.values.first,
    );
    final isHigh = output.value == SignalState.high;

    // Component label
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'INPUT',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(rect.center.dx - labelPainter.width / 2, rect.top + 12),
    );

    // Switch track
    final trackRect = Rect.fromCenter(
      center: rect.center,
      width: 42,
      height: 16,
    );
    final trackPaint = Paint()
      ..color = isHigh
          ? AppTheme.signalHigh.withValues(alpha: 0.25)
          : AppTheme.surfaceLight;
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(8)),
      trackPaint,
    );

    // Switch knob
    final knobX = isHigh ? trackRect.right - 10 : trackRect.left + 10;
    canvas.drawCircle(
      Offset(knobX, rect.center.dy),
      9,
      Paint()..color = isHigh ? AppTheme.signalHigh : AppTheme.textSecondary,
    );
  }

  void _drawLED(Canvas canvas, ChipInstance chip, Rect rect) {
    final input = chip.pinStates.values.firstWhere(
      (p) => p.direction == PinDirection.input,
      orElse: () => chip.pinStates.values.first,
    );
    final isLit = input.value == SignalState.high;

    // Component label
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'LED',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(rect.center.dx - labelPainter.width / 2, rect.top + 12),
    );

    // Bulb glow
    if (isLit) {
      canvas.drawCircle(
        rect.center,
        22,
        Paint()..color = AppTheme.signalHigh.withValues(alpha: 0.18),
      );
    }

    // Bulb body
    canvas.drawCircle(
      rect.center,
      14,
      Paint()..color = isLit ? AppTheme.signalHigh : AppTheme.signalHighZ,
    );
    canvas.drawCircle(
      rect.center,
      14,
      Paint()
        ..color = AppTheme.chipBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ---- Pins ----

  void _drawPins(Canvas canvas, ChipInstance chip) {
    final positions = chip.pinAbsolutePositions;

    for (final entry in chip.pinStates.entries) {
      final pinNumber = entry.key;
      final pinState = entry.value;
      final pos = positions[pinNumber];
      if (pos == null) continue;

      final pinId = chip.pinId(pinNumber);
      final isPinSelected = pinId == selectedPinId;

      // Pin circle
      final pinColor = _pinColor(pinState);
      final circlePaint = Paint()
        ..color = pinColor
        ..style = PaintingStyle.fill;

      // Selection ring
      if (isPinSelected) {
        canvas.drawCircle(
          pos,
          9.0,
          Paint()
            ..color = AppTheme.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0,
        );
      }

      canvas.drawCircle(pos, 5.5, circlePaint);

      // Pin border
      canvas.drawCircle(
        pos,
        5.5,
        Paint()
          ..color = pinColor.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Pin label (outside the chip)
      final isLeft = pos.dx < chip.rect.center.dx;
      final labelPainter = TextPainter(
        text: TextSpan(
          text: pinState.label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 9,
            fontWeight: isPinSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      labelPainter.layout();
      final labelX = isLeft ? pos.dx - 8 - labelPainter.width : pos.dx + 8;
      labelPainter.paint(
        canvas,
        Offset(labelX, pos.dy - labelPainter.height / 2),
      );
    }
  }

  Color _pinColor(PinState pin) {
    switch (pin.direction) {
      case PinDirection.input:
        return AppTheme.pinInput;
      case PinDirection.output:
        return AppTheme.colorForSignal(pin.value);
      case PinDirection.power:
        return AppTheme.pinPower;
      case PinDirection.ground:
        return AppTheme.pinGround;
    }
  }
}
