import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../models/chip_instance.dart';
import '../models/circuit_grid.dart';
import '../models/circuit.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';
import '../models/wire.dart';
import '../providers/editor_provider.dart';
import '../theme/app_theme.dart';

/// Hard collision margin: wires may never enter this area around a visible
/// component body.
const double _hardClearance = 2.0;

/// Preferred clearance: routing tries to stay this far away when space
/// allows, but it is not a hard obstacle.
const double _softClearance = kGridUnit;

/// A state used by the fallback A* search.
class _FallbackSearchNode implements Comparable<_FallbackSearchNode> {
  final double priority;
  final int nodeId;
  final double gCost;

  const _FallbackSearchNode({
    required this.priority,
    required this.nodeId,
    required this.gCost,
  });

  @override
  int compareTo(_FallbackSearchNode other) {
    final byPriority = priority.compareTo(other.priority);
    return byPriority != 0 ? byPriority : nodeId.compareTo(other.nodeId);
  }
}

/// Below this view scale only pin numbers are drawn; at or above it the
/// pin function name is appended as a secondary label.
const _pinNameZoomThreshold = 0.8;

/// A single already-routed wire together with its electrical net id.
class _RoutedWireGeometry {
  final String wireId;
  final int netId;
  final List<Offset> path;

  const _RoutedWireGeometry({
    required this.wireId,
    required this.netId,
    required this.path,
  });
}

/// Provides existing wire geometry and net membership for crossing scoring.
///
/// The base paths are computed without crossing optimization. New candidate
/// paths are then scored against these existing paths, which keeps existing
/// wires stable while a new wire is being routed.
class WireRoutingContext {
  final List<_RoutedWireGeometry> _geometries;
  final Map<String, int> _wireNetIds;

  WireRoutingContext._(this._geometries, this._wireNetIds);

  factory WireRoutingContext.fromCircuit(Circuit circuit) {
    final pinPositions = circuit.allPinPositions;
    final wireNetIds = _buildWireNetIds(circuit);
    final geometries = <_RoutedWireGeometry>[];

    for (final wire in circuit.wires) {
      final p1 = pinPositions[wire.pinIdA];
      final p2 = pinPositions[wire.pinIdB];
      if (p1 == null || p2 == null) continue;

      final chip1 = _chipForWireEndpoint(wire.pinIdA, circuit.chips);
      final chip2 = _chipForWireEndpoint(wire.pinIdB, circuit.chips);
      final path = computeWireRoute(p1, p2, chip1, chip2, circuit.chips);

      geometries.add(_RoutedWireGeometry(
        wireId: wire.id,
        netId: wireNetIds[wire.id] ?? -1,
        path: path,
      ));
    }

    return WireRoutingContext._(geometries, wireNetIds);
  }

  int? netIdForWire(String wireId) => _wireNetIds[wireId];

  /// Returns a new context with [wireId]'s geometry replaced by [path].
  ///
  /// Painter and hit-test use this while walking wires in order, so each
  /// wire avoids the already-optimized paths of earlier wires instead of
  /// only avoiding their stale base paths.
  WireRoutingContext replacePath(String wireId, List<Offset> path) {
    final geometries = _geometries.map((geometry) {
      if (geometry.wireId != wireId) return geometry;
      return _RoutedWireGeometry(
        wireId: geometry.wireId,
        netId: geometry.netId,
        path: path,
      );
    }).toList();
    return WireRoutingContext._(geometries, _wireNetIds);
  }

  int crossingCount(
    List<Offset> candidatePath, {
    String? excludeWireId,
    int? currentNetId,
  }) {
    var count = 0;
    for (final geometry in _geometries) {
      if (excludeWireId != null && geometry.wireId == excludeWireId) continue;
      if (currentNetId != null && geometry.netId == currentNetId) continue;
      count += _countPathCrossings(candidatePath, geometry.path);
    }
    return count;
  }

  double overlapLength(
    List<Offset> candidatePath, {
    String? excludeWireId,
    int? currentNetId,
  }) {
    var length = 0.0;
    for (final geometry in _geometries) {
      if (excludeWireId != null && geometry.wireId == excludeWireId) continue;
      if (currentNetId != null && geometry.netId == currentNetId) continue;
      length += _countPathOverlapLength(candidatePath, geometry.path);
    }
    return length;
  }

  /// Longest same-direction overlap with any single existing wire.
  double maxOverlapLength(
    List<Offset> candidatePath, {
    String? excludeWireId,
    int? currentNetId,
  }) {
    var maxLength = 0.0;
    for (final geometry in _geometries) {
      if (excludeWireId != null && geometry.wireId == excludeWireId) continue;
      if (currentNetId != null && geometry.netId == currentNetId) continue;
      final overlap = _countPathOverlapLength(candidatePath, geometry.path);
      if (overlap > maxLength) maxLength = overlap;
    }
    return maxLength;
  }
}

/// Finds the chip that owns a wire endpoint pin.
ChipInstance? _chipForWireEndpoint(String pinId, List<ChipInstance> chips) {
  for (final chip in chips) {
    if (pinId.startsWith('${chip.id}_')) return chip;
  }
  return null;
}

/// Assigns an integer net id to every wire using union-find over pins.
Map<String, int> _buildWireNetIds(Circuit circuit) {
  final parent = <String, String>{};

  String find(String node) {
    var root = node;
    while (parent[root] != root) {
      root = parent[root]!;
    }
    while (parent[node] != node) {
      final next = parent[node]!;
      parent[node] = root;
      node = next;
    }
    return root;
  }

  void ensure(String node) {
    parent.putIfAbsent(node, () => node);
  }

  void union(String a, String b) {
    ensure(a);
    ensure(b);
    final rootA = find(a);
    final rootB = find(b);
    if (rootA != rootB) parent[rootB] = rootA;
  }

  for (final wire in circuit.wires) {
    union(wire.pinIdA, wire.pinIdB);
  }

  final rootIds = <String, int>{};
  final result = <String, int>{};
  for (final wire in circuit.wires) {
    final root = find(wire.pinIdA);
    result[wire.id] = rootIds.putIfAbsent(root, () => rootIds.length);
  }
  return result;
}

double _pathLength(List<Offset> path) {
  var length = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    length += (path[i] - path[i + 1]).distance;
  }
  return length;
}

bool _strictlyInside(double value, double a, double b) {
  final low = min(a, b);
  final high = max(a, b);
  return value > low && value < high;
}

int _countPathCrossings(List<Offset> first, List<Offset> second) {
  var count = 0;
  for (var i = 0; i < first.length - 1; i++) {
    final a1 = first[i];
    final a2 = first[i + 1];
    final aHorizontal = (a1.dy - a2.dy).abs() < 0.01;

    for (var j = 0; j < second.length - 1; j++) {
      final b1 = second[j];
      final b2 = second[j + 1];
      final bHorizontal = (b1.dy - b2.dy).abs() < 0.01;
      if (aHorizontal == bHorizontal) continue;

      if (aHorizontal) {
        final y = a1.dy;
        final x = b1.dx;
        if (_strictlyInside(x, a1.dx, a2.dx) &&
            _strictlyInside(y, b1.dy, b2.dy)) {
          count++;
        }
      } else {
        final x = a1.dx;
        final y = b1.dy;
        if (_strictlyInside(y, a1.dy, a2.dy) &&
            _strictlyInside(x, b1.dx, b2.dx)) {
          count++;
        }
      }
    }
  }
  return count;
}

double _countPathOverlapLength(List<Offset> first, List<Offset> second) {
  var length = 0.0;
  for (var i = 0; i < first.length - 1; i++) {
    final a1 = first[i];
    final a2 = first[i + 1];
    final aHorizontal = (a1.dy - a2.dy).abs() < 0.01;

    for (var j = 0; j < second.length - 1; j++) {
      final b1 = second[j];
      final b2 = second[j + 1];
      final bHorizontal = (b1.dy - b2.dy).abs() < 0.01;
      if (aHorizontal != bHorizontal) continue;

      if (aHorizontal) {
        if ((a1.dy - b1.dy).abs() >= 0.01) continue;
        final low = max(min(a1.dx, a2.dx), min(b1.dx, b2.dx));
        final high = min(max(a1.dx, a2.dx), max(b1.dx, b2.dx));
        if (high > low) length += high - low;
      } else {
        if ((a1.dx - b1.dx).abs() >= 0.01) continue;
        final low = max(min(a1.dy, a2.dy), min(b1.dy, b2.dy));
        final high = min(max(a1.dy, a2.dy), max(b1.dy, b2.dy));
        if (high > low) length += high - low;
      }
    }
  }
  return length;
}

double _countPathInsideRectsLength(
  List<Offset> path,
  List<Rect> rects,
) {
  var length = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    final a = path[i];
    final b = path[i + 1];
    final horizontal = (a.dy - b.dy).abs() < 0.01;
    for (final rect in rects) {
      if (horizontal) {
        if (a.dy <= rect.top || a.dy >= rect.bottom) continue;
        final low = max(min(a.dx, b.dx), rect.left);
        final high = min(max(a.dx, b.dx), rect.right);
        if (high > low) length += high - low;
      } else {
        if (a.dx <= rect.left || a.dx >= rect.right) continue;
        final low = max(min(a.dy, b.dy), rect.top);
        final high = min(max(a.dy, b.dy), rect.bottom);
        if (high > low) length += high - low;
      }
    }
  }
  return length;
}

bool _isGridAligned(Offset point) {
  return (point.dx - snapValueToGrid(point.dx)).abs() < 0.01 &&
      (point.dy - snapValueToGrid(point.dy)).abs() < 0.01;
}

double _scorePath(
  List<Offset> path,
  WireRoutingContext context,
  String? currentWireId,
  List<Rect> softObstacleRects,
) {
  final currentNetId =
      currentWireId == null ? null : context.netIdForWire(currentWireId);
  final crossings = context.crossingCount(
    path,
    excludeWireId: currentWireId,
    currentNetId: currentNetId,
  );
  final overlapLength = context.overlapLength(
    path,
    excludeWireId: currentWireId,
    currentNetId: currentNetId,
  );
  final maxOverlapLength = context.maxOverlapLength(
    path,
    excludeWireId: currentWireId,
    currentNetId: currentNetId,
  );
  if (maxOverlapLength > 0.01) {
    return double.infinity;
  }
  final overlapGrids = overlapLength / kGridUnit;
  // A same-direction overlap longer than one grid cell is treated as a
  // near-forbidden item, so candidates with shorter overlaps win unless
  // no clean path exists at all.
  final overlapPenalty =
      overlapGrids <= 1.0 ? overlapGrids * 500.0 : overlapGrids * 100000.0;
  final softOverlapLength =
      _countPathInsideRectsLength(path, softObstacleRects);
  final softPenalty = softOverlapLength / kGridUnit * 40.0;
  final offGridSegments = path.where((point) => !_isGridAligned(point)).length;
  final length = _pathLength(path) / kGridUnit;
  final bends = path.length > 2 ? path.length - 2 : 0;

  // Crossings and long overlaps are the dominant costs; length and bends
  // only break ties.
  return crossings * 1000.0 +
      overlapPenalty +
      softPenalty +
      offGridSegments * 10.0 +
      length +
      bends * 20.0;
}

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
  const branchDistance = kGridUnit;
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

  final routingContext = WireRoutingContext.fromCircuit(circuit);
  final path = computeWireRoute(
    p1,
    p2,
    chip1,
    chip2,
    circuit.chips,
    routingContext: routingContext,
    currentWireId: anchorWire.id,
  );
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
  const candidateStep = kGridUnit / 2;
  if (dir1 == dir2) {
    final base = (dir1 > 0)
        ? max(p1.dx, p2.dx) + exitMargin
        : min(p1.dx, p2.dx) - exitMargin;
    candidates.add(base);
    for (int i = 1; i < 100; i++) {
      candidates.add(base + dir1 * i * candidateStep);
    }
  } else {
    final mid = snapValueToGrid((p1.dx + p2.dx) / 2);
    candidates.add(mid);
    for (int i = 1; i < 100; i++) {
      candidates.add(mid + i * candidateStep);
      candidates.add(mid - i * candidateStep);
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

/// Verifies every segment of [path] against the chip obstacle list.
///
/// The first segment may skip the source chip and the last segment may skip
/// the target chip, because leaving/entering a pin at a chip edge is legal.
bool _pathClearOfChips(
  List<Offset> path,
  List<Rect> obstacleRects,
  List<String> chipIds, {
  String? startSkipId,
  String? endSkipId,
}) {
  for (var i = 0; i < path.length - 1; i++) {
    var skipId = '';
    if (i == 0) skipId = startSkipId ?? '';
    if (i == path.length - 2) skipId = endSkipId ?? skipId;
    if (_segHitsChip(
      path[i],
      path[i + 1],
      obstacleRects,
      chipIds,
      skipId.isEmpty ? null : skipId,
    )) {
      return false;
    }
  }
  return true;
}

/// Builds one Phase 1 stair-step candidate for [midX].
List<Offset> _buildPhase1Path(
  Offset start,
  Offset end,
  double dir1,
  double dir2,
  double midX,
) {
  // In a narrow corridor the preferred 20px lead-out is not always
  // available. Use the pin edge as the minimum instead, so the vertical
  // column starts at the end of the horizontal lead-out rather than in
  // the middle of a backtracking segment.
  final exit1X = (dir1 > 0) ? max(start.dx, midX) : min(start.dx, midX);
  final exit2X = (dir2 > 0) ? max(end.dx, midX) : min(end.dx, midX);

  return [
    start,
    Offset(exit1X, start.dy),
    Offset(midX, start.dy),
    Offset(midX, end.dy),
    Offset(exit2X, end.dy),
    end,
  ];
}

/// Builds both "route above" and "route below" candidates in
/// distance-preferred order, validating them against all chip obstacles.
List<List<Offset>> _routeAroundCandidates(
  Offset p1,
  Offset p2,
  double dir1,
  double dir2,
  double exitMargin,
  List<Rect> obstacleRects,
  List<String> chipIds,
) {
  const cornerMargin = kGridUnit;

  final ex1 = p1.dx + dir1 * exitMargin;
  final ex2 = p2.dx + dir2 * exitMargin;
  final routeMinX = min(ex1, ex2);
  final routeMaxX = max(ex1, ex2);
  final yMin = min(p1.dy, p2.dy);
  final yMax = max(p1.dy, p2.dy);

  var highestTop = double.infinity;
  var lowestBottom = double.negativeInfinity;
  var hasObstacle = false;
  for (final r in obstacleRects) {
    if (r.bottom > yMin && r.top < yMax) {
      if (r.right > routeMinX && r.left < routeMaxX) {
        hasObstacle = true;
        highestTop = min(highestTop, r.top);
        lowestBottom = max(lowestBottom, r.bottom);
      }
    }
  }

  if (!hasObstacle) {
    final mx = snapValueToGrid((ex1 + ex2) / 2);
    final direct = <Offset>[
      p1,
      Offset(ex1, p1.dy),
      Offset(mx, p1.dy),
      Offset(mx, p2.dy),
      Offset(ex2, p2.dy),
      p2,
    ];
    if (_pathClearOfChips(direct, obstacleRects, chipIds)) {
      return [direct];
    }

    // A chip spans the full Y range, so re-detect obstacles across the
    // complete X span and fall through to top/bottom routing.
    hasObstacle = true;
    highestTop = double.infinity;
    lowestBottom = double.negativeInfinity;
    for (final r in obstacleRects) {
      if (r.right > routeMinX && r.left < routeMaxX) {
        highestTop = min(highestTop, r.top);
        lowestBottom = max(lowestBottom, r.bottom);
      }
    }
  }

  var minAllX = double.infinity;
  var maxAllX = double.negativeInfinity;
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

  List<Offset> buildAround(double clearanceY) => [
        p1,
        Offset(ex1, p1.dy),
        Offset(outerX, p1.dy),
        Offset(outerX, clearanceY),
        Offset(ex2, clearanceY),
        Offset(ex2, p2.dy),
        p2,
      ];

  final goAbove = (p1.dy - highestTop).abs() + (p2.dy - highestTop).abs() <
      (p1.dy - lowestBottom).abs() + (p2.dy - lowestBottom).abs();
  final options = <List<Offset>>[];

  void addIfValid(double clearanceY) {
    final path = buildAround(clearanceY);
    if (_pathClearOfChips(path, obstacleRects, chipIds)) {
      options.add(path);
    }
  }

  if (goAbove) {
    if (highestTop.isFinite) addIfValid(highestTop - cornerMargin);
    if (lowestBottom.isFinite) addIfValid(lowestBottom + cornerMargin);
  } else {
    if (lowestBottom.isFinite) addIfValid(lowestBottom + cornerMargin);
    if (highestTop.isFinite) addIfValid(highestTop - cornerMargin);
  }

  return options;
}

bool _pointInsideAnyObstacle(Offset point, List<Rect> obstacleRects) {
  for (final rect in obstacleRects) {
    if (point.dx > rect.left &&
        point.dx < rect.right &&
        point.dy > rect.top &&
        point.dy < rect.bottom) {
      return true;
    }
  }
  return false;
}

/// Simplifies a grid path by removing collinear intermediate points.
List<Offset> _simplifyGridPath(List<Offset> path) {
  if (path.length <= 2) return List<Offset>.from(path);

  final result = <Offset>[path.first];
  for (var i = 1; i < path.length - 1; i++) {
    final previous = result.last;
    final current = path[i];
    final next = path[i + 1];
    if (current == previous) continue;
    final straight = (previous.dx == current.dx && current.dx == next.dx) ||
        (previous.dy == current.dy && current.dy == next.dy);
    if (!straight) result.add(current);
  }
  result.add(path.last);
  return result;
}

/// Last-resort orthogonal route on a 10px sub-grid.
///
/// The search is weighted: component collisions are hard blockers, while
/// same-direction overlap with other nets carries a very high cost. It
/// therefore avoids the remaining overlap cases that fixed Phase 1/Phase 2
/// candidates cannot represent.
List<Offset> _fallbackOrthogonalPath(
  Offset start,
  Offset end,
  List<Rect> obstacleRects,
  List<String> chipIds,
  WireRoutingContext? routingContext,
  String? currentWireId,
  List<Rect> softObstacleRects, {
  String? startSkipId,
  String? endSkipId,
}) {
  const subGrid = kGridUnit / 2;
  const maxGridIndex = 1000;

  int gridX(double value) =>
      (value / subGrid).round().clamp(0, maxGridIndex).toInt();
  int gridY(double value) =>
      (value / subGrid).round().clamp(0, maxGridIndex).toInt();
  int nodeId(int x, int y) => x * (maxGridIndex + 1) + y;

  final startX = gridX(start.dx);
  final startY = gridY(start.dy);
  final endX = gridX(end.dx);
  final endY = gridY(end.dy);
  final startId = nodeId(startX, startY);
  final endId = nodeId(endX, endY);
  final context = routingContext;
  final currentNetId =
      currentWireId == null ? null : context?.netIdForWire(currentWireId);

  List<Offset> search(int minX, int maxX, int minY, int maxY) {
    final gScore = <int, double>{startId: 0.0};
    final cameFrom = <int, int>{};
    final queue = HeapPriorityQueue<_FallbackSearchNode>(
      (a, b) => a.compareTo(b),
    );

    double heuristic(int id) {
      final x = id ~/ (maxGridIndex + 1);
      final y = id % (maxGridIndex + 1);
      return (endX - x).abs().toDouble() + (endY - y).abs().toDouble();
    }

    queue.add(_FallbackSearchNode(
      priority: heuristic(startId),
      nodeId: startId,
      gCost: 0.0,
    ));

    bool nodeBlocked(int x, int y) {
      if (x == startX && y == startY) return false;
      if (x == endX && y == endY) return false;
      return _pointInsideAnyObstacle(
        Offset(x * subGrid, y * subGrid),
        obstacleRects,
      );
    }

    bool segmentBlocked(int fromId, int toId) {
      final fromX = fromId ~/ (maxGridIndex + 1);
      final fromY = fromId % (maxGridIndex + 1);
      final toX = toId ~/ (maxGridIndex + 1);
      final toY = toId % (maxGridIndex + 1);

      String? skipId;
      if (fromId == startId) skipId = startSkipId;
      if (toId == endId) skipId = endSkipId ?? skipId;

      return _segHitsChip(
        Offset(fromX * subGrid, fromY * subGrid),
        Offset(toX * subGrid, toY * subGrid),
        obstacleRects,
        chipIds,
        skipId,
      );
    }

    double? segmentCost(int fromId, int toId) {
      if (segmentBlocked(fromId, toId)) return null;

      final fromX = fromId ~/ (maxGridIndex + 1);
      final fromY = fromId % (maxGridIndex + 1);
      final toX = toId ~/ (maxGridIndex + 1);
      final toY = toId % (maxGridIndex + 1);
      final fromPoint = Offset(fromX * subGrid, fromY * subGrid);
      final toPoint = Offset(toX * subGrid, toY * subGrid);

      var cost = 1.0;
      if (context != null) {
        final overlap = context!.maxOverlapLength(
          [fromPoint, toPoint],
          excludeWireId: currentWireId,
          currentNetId: currentNetId,
        );
        cost += overlap / subGrid * 100000.0;
      }

      final softOverlap =
          _countPathInsideRectsLength([fromPoint, toPoint], softObstacleRects);
      cost += softOverlap / subGrid * 0.5;
      if (!_isGridAligned(toPoint)) cost += 0.5;
      return cost;
    }

    const directions = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ];

    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (node.gCost > (gScore[node.nodeId] ?? double.infinity) + 0.0001) {
        continue;
      }
      if (node.nodeId == endId) break;

      final currentX = node.nodeId ~/ (maxGridIndex + 1);
      final currentY = node.nodeId % (maxGridIndex + 1);

      for (final direction in directions) {
        final nextX = currentX + direction[0];
        final nextY = currentY + direction[1];
        if (nextX < minX || nextX > maxX || nextY < minY || nextY > maxY) {
          continue;
        }

        final nextId = nodeId(nextX, nextY);
        if (nodeBlocked(nextX, nextY)) continue;
        final moveCost = segmentCost(node.nodeId, nextId);
        if (moveCost == null) continue;

        final tentative = node.gCost + moveCost;
        if (tentative < (gScore[nextId] ?? double.infinity)) {
          gScore[nextId] = tentative;
          cameFrom[nextId] = node.nodeId;
          queue.add(_FallbackSearchNode(
            priority: tentative + heuristic(nextId),
            nodeId: nextId,
            gCost: tentative,
          ));
        }
      }
    }

    if (!cameFrom.containsKey(endId)) {
      return const <Offset>[];
    }

    final reversedIds = <int>[];
    var current = endId;
    while (current != startId) {
      reversedIds.add(current);
      final previous = cameFrom[current];
      if (previous == null) return const <Offset>[];
      current = previous;
    }
    reversedIds.add(startId);

    final points = <Offset>[];
    for (final id in reversedIds.reversed) {
      final x = id ~/ (maxGridIndex + 1);
      final y = id % (maxGridIndex + 1);
      points.add(Offset(x * subGrid, y * subGrid));
    }
    return _simplifyGridPath(points);
  }

  var minX = min(gridX(start.dx), gridX(end.dx)) - 4;
  var maxX = max(gridX(start.dx), gridX(end.dx)) + 4;
  var minY = min(gridY(start.dy), gridY(end.dy)) - 4;
  var maxY = max(gridY(start.dy), gridY(end.dy)) + 4;

  for (final rect in obstacleRects) {
    minX = min(minX, (rect.left / subGrid).floor() - 4);
    maxX = max(maxX, (rect.right / subGrid).ceil() + 4);
    minY = min(minY, (rect.top / subGrid).floor() - 4);
    maxY = max(maxY, (rect.bottom / subGrid).ceil() + 4);
  }

  minX = minX.clamp(0, maxGridIndex).toInt();
  maxX = maxX.clamp(0, maxGridIndex).toInt();
  minY = minY.clamp(0, maxGridIndex).toInt();
  maxY = maxY.clamp(0, maxGridIndex).toInt();

  var path = search(minX, maxX, minY, maxY);
  if (path.isEmpty) {
    path = search(0, maxGridIndex, 0, maxGridIndex);
  }

  if (path.isEmpty) {
    var minLeft = double.infinity;
    var maxRight = double.negativeInfinity;
    var minTop = double.infinity;
    var maxBottom = double.negativeInfinity;
    for (final rect in obstacleRects) {
      minLeft = min(minLeft, rect.left);
      maxRight = max(maxRight, rect.right);
      minTop = min(minTop, rect.top);
      maxBottom = max(maxBottom, rect.bottom);
    }
    if (!minLeft.isFinite) {
      minLeft = min(start.dx, end.dx) - kGridUnit;
      maxRight = max(start.dx, end.dx) + kGridUnit;
      minTop = min(start.dy, end.dy) - kGridUnit;
      maxBottom = max(start.dy, end.dy) + kGridUnit;
    }
    final left = minLeft - kGridUnit;
    final top = minTop - kGridUnit;
    path = [
      start,
      Offset(left, start.dy),
      Offset(left, top),
      Offset(end.dx, top),
      end,
    ];
  }

  return path;
}

/// Computes the orthogonal (Manhattan) path between two points, avoiding
/// chip bodies.  This is the standalone routing function shared by the
/// painter, hit‑test, and junction‑point computation.
List<Offset> computeWireRoute(Offset p1, Offset p2, ChipInstance? chip1,
    ChipInstance? chip2, List<ChipInstance> allChips,
    {Offset? overrideStart,
    Offset? overrideEnd,
    WireRoutingContext? routingContext,
    String? currentWireId}) {
  const exitMargin = kGridUnit;

  final start = overrideStart ?? p1;
  final end = overrideEnd ?? p2;
  final startSkipId = overrideStart != null ? null : chip1?.id;
  final endSkipId = overrideEnd != null ? null : chip2?.id;

  final softObstacleRects = <Rect>[];
  final hardObstacleRects = <Rect>[];
  final chipIds = <String>[];
  for (final chip in allChips) {
    final r = chip.rect;
    softObstacleRects.add(Rect.fromLTRB(
      r.left - kGridUnit,
      r.top - kGridUnit,
      r.right + kGridUnit,
      r.bottom + kGridUnit,
    ));
    hardObstacleRects.add(Rect.fromLTRB(
      r.left - _hardClearance,
      r.top - _hardClearance,
      r.right + _hardClearance,
      r.bottom + _hardClearance,
    ));
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
    final pathAValid = !_segHitsChip(
            start, cornerA, hardObstacleRects, chipIds, startSkipId) &&
        !_segHitsChip(cornerA, end, hardObstacleRects, chipIds, skipA2);

    // Path B: horizontal first  →  └─
    final cornerB = Offset(end.dx, start.dy);
    final skipB2 = entersFromCorrectSide(cornerB) ? endSkipId : null;
    final pathBValid = !_segHitsChip(
            start, cornerB, hardObstacleRects, chipIds, startSkipId) &&
        !_segHitsChip(cornerB, end, hardObstacleRects, chipIds, skipB2);

    if (routingContext == null) {
      if (pathAValid) return [start, cornerA, end];
      if (pathBValid) return [start, cornerB, end];
    } else {
      List<Offset>? bestBranchPath;
      var bestBranchScore = double.infinity;

      void consider(List<Offset> path) {
        final score = _scorePath(
          path,
          routingContext!,
          currentWireId,
          softObstacleRects,
        );
        if (score < bestBranchScore) {
          bestBranchScore = score;
          bestBranchPath = path;
        }
      }

      if (pathAValid) consider([start, cornerA, end]);
      if (pathBValid) consider([start, cornerB, end]);

      if (bestBranchPath != null && bestBranchScore.isFinite) {
        return bestBranchPath!;
      }
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

  List<Offset>? bestPath;
  var bestScore = double.infinity;
  for (final midX in candidates) {
    final path = _buildPhase1Path(
      start,
      end,
      dir1,
      dir2,
      midX,
    );
    if (!_pathClearOfChips(
      path,
      hardObstacleRects,
      chipIds,
      startSkipId: startSkipId,
      endSkipId: endSkipId,
    )) {
      continue;
    }

    if (routingContext == null) {
      return path;
    }

    final score = _scorePath(
      path,
      routingContext,
      currentWireId,
      softObstacleRects,
    );
    if (score < bestScore) {
      bestScore = score;
      bestPath = path;
    }
  }

  if (bestPath != null) {
    return bestPath;
  }

  // ── Phase 2: route around obstacles via top/bottom ──────────────
  final options = _routeAroundCandidates(
      start, end, dir1, dir2, exitMargin, softObstacleRects, chipIds);
  if (options.isEmpty) {
    return _fallbackOrthogonalPath(
      start,
      end,
      hardObstacleRects,
      chipIds,
      routingContext,
      currentWireId,
      softObstacleRects,
      startSkipId: startSkipId,
      endSkipId: endSkipId,
    );
  }
  if (routingContext == null) {
    return options.first;
  }

  var bestOption = options.first;
  bestScore = _scorePath(
    bestOption,
    routingContext,
    currentWireId,
    softObstacleRects,
  );
  for (final option in options.skip(1)) {
    final score = _scorePath(
      option,
      routingContext,
      currentWireId,
      softObstacleRects,
    );
    if (score < bestScore) {
      bestScore = score;
      bestOption = option;
    }
  }
  if (bestScore.isInfinite) {
    return _fallbackOrthogonalPath(
      start,
      end,
      hardObstacleRects,
      chipIds,
      routingContext,
      currentWireId,
      softObstacleRects,
      startSkipId: startSkipId,
      endSkipId: endSkipId,
    );
  }
  return bestOption;
}

/// Returns the branch point for a pin that already has wires connected.
/// CustomPainter that renders the entire circuit canvas.
class CircuitPainter extends CustomPainter {
  final Circuit circuit;
  final ThemePalette palette;
  final ChipStyle chipStyle;
  final bool showPins;
  final String? selectedPinId;
  final String? selectedChipId;
  final String? selectedWireId;
  final Offset? ghostWireStart; // circuit-coordinate start of ghost wire
  final Offset? ghostWireEnd; // circuit-coordinate end of ghost wire
  final double zoomScale; // current view scale (1.0 = 100%)

  CircuitPainter({
    required this.circuit,
    required this.palette,
    this.chipStyle = ChipStyle.industrial,
    this.showPins = true,
    this.selectedPinId,
    this.selectedChipId,
    this.selectedWireId,
    this.ghostWireStart,
    this.ghostWireEnd,
    this.zoomScale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _canvasColor,
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
        palette != oldDelegate.palette ||
        chipStyle != oldDelegate.chipStyle ||
        showPins != oldDelegate.showPins ||
        selectedPinId != oldDelegate.selectedPinId ||
        selectedChipId != oldDelegate.selectedChipId ||
        selectedWireId != oldDelegate.selectedWireId ||
        ghostWireStart != oldDelegate.ghostWireStart ||
        ghostWireEnd != oldDelegate.ghostWireEnd ||
        zoomScale != oldDelegate.zoomScale;
  }

  // ---- Grid ----

  void _drawGrid(Canvas canvas, Size size) {
    const spacing = kGridUnit;
    final paint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.35, paint);
      }
    }
  }

  // ---- Wires (orthogonal routing) ----

  void _drawWires(Canvas canvas) {
    final pinPositions = circuit.allPinPositions;
    var routingContext = WireRoutingContext.fromCircuit(circuit);

    // Group wires by pin to detect multi-wire pins that need branching
    final wiresForPin = <String, List<Wire>>{};
    for (final wire in circuit.wires) {
      wiresForPin.putIfAbsent(wire.pinIdA, () => []).add(wire);
      wiresForPin.putIfAbsent(wire.pinIdB, () => []).add(wire);
    }

    // Anchor vertical segments are filled lazily as each wire is routed.
    final anchorVSegs = <String, VSegment?>{};

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
          overrideStart: overrideStart,
          overrideEnd: overrideEnd,
          routingContext: routingContext,
          currentWireId: wire.id);

      // Remember the anchor's vertical segment for later branch wires.
      if (pinAWires.isNotEmpty && pinAWires.first.id == wire.id) {
        anchorVSegs[wire.pinIdA] = findVerticalSegment(path);
      }
      if (pinBWires.isNotEmpty && pinBWires.first.id == wire.id) {
        anchorVSegs[wire.pinIdB] = findVerticalSegment(path);
      }

      // Later wires avoid this wire's optimized path, not its stale base
      // path.
      routingContext = routingContext.replacePath(wire.id, path);

      final isSelected = wire.id == selectedWireId;
      final color = isSelected ? palette.wireSelected : _wireColor(wire);

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
      {Offset? overrideStart,
      Offset? overrideEnd,
      WireRoutingContext? routingContext,
      String? currentWireId}) {
    return computeWireRoute(p1, p2, chip1, chip2, circuit.chips,
        overrideStart: overrideStart,
        overrideEnd: overrideEnd,
        routingContext: routingContext,
        currentWireId: currentWireId);
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
    return palette.colorForSignal(state ?? SignalState.unknown);
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

      dotPaint.color =
          palette.colorForSignal(state ?? SignalState.unknown);

      // Junction dot at the pin itself
      canvas.drawCircle(pos, 4.5, dotPaint);
      canvas.drawCircle(
          pos,
          4.5,
          Paint()
          ..color = _canvasColor
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
              ..color = _canvasColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0);
      }
    }
  }

  // ---- Ghost Wire ----

  void _drawGhostWire(Canvas canvas) {
    if (ghostWireStart == null || ghostWireEnd == null) return;
    final paint = Paint()
      ..color = palette.accent.withValues(alpha: 0.6)
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

  bool get _refinedStyle => chipStyle == ChipStyle.refined;

  bool get _industrialStyle => chipStyle == ChipStyle.industrial;

  Color get _canvasColor => _industrialStyle
      ? palette.canvasBgIndustrial
      : palette.canvasBg;

  Color get _gridColor => _industrialStyle
      ? palette.gridDotIndustrial
      : palette.gridDot;

  Color get _chipAccentColor =>
      _refinedStyle ? palette.chipAccentRefined : palette.accent;

  Color get _chipLabelColor =>
      _refinedStyle
          ? palette.chipTextRefined
          : palette.chipTextIndustrial;

  Color get _chipLabelSecondaryColor => _refinedStyle
      ? palette.chipTextSecondaryRefined
      : palette.chipTextSecondaryIndustrial;

  void _drawChip(Canvas canvas, ChipInstance chip) {
    final rect = chip.rect;
    final isSelected = chip.id == selectedChipId;
    final isRefined = chipStyle == ChipStyle.refined;

    // Chip body
    final bodyColor =
        isRefined ? palette.chipBodyRefined : palette.chipBodyIndustrial;
    final bodyPaint = Paint()..style = PaintingStyle.fill;
    if (isRefined) {
      // Pearl-like sheen: gray base with a white gloss sweeping from the
      // top-left toward the bottom-right.
      bodyPaint.shader = LinearGradient(
        begin: const Alignment(-0.45, -0.5),
        end: const Alignment(0.55, 0.75),
        colors: [
          Color.lerp(bodyColor, palette.chipGlossRefined, 0.62)!,
          bodyColor,
          Color.lerp(bodyColor, Colors.black, 0.16)!,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(rect);
    } else {
      bodyPaint.color = bodyColor;
    }
    final Paint borderPaint;
    if (isRefined && !isSelected) {
      // The refined edge is a gradient: lighter at the top, darker at the
      // bottom, giving the chip a dimensional, non-flat outline.
      borderPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
                palette.chipGlossRefined, palette.chipBorderRefined, 0.25)!,
            palette.chipBorderRefined,
            Color.lerp(palette.chipBorderRefined, Colors.black, 0.18)!,
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(rect)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
    } else {
      borderPaint = Paint()
        ..color = isSelected
            ? palette.chipBorderSelected
            : palette.chipBorderIndustrial
        ..strokeWidth = isSelected ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;
    }

    final radius = isRefined ? 12.0 : 6.0;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final shadowPath = Path()..addRRect(rrect);
    canvas.drawShadow(
      shadowPath,
      isRefined
          ? (palette.isDark
              ? const Color(0xCC000000)
              : const Color(0x45405A8A))
          : palette.glassShadow,
      isRefined ? 10 : 5,
      true,
    );
    canvas.drawRRect(rrect, bodyPaint);

    // Soft pearl reflection inside the top area.
    if (isRefined) {
      final sheenCenter =
          rect.topLeft + Offset(rect.width * 0.28, rect.height * 0.22);
      final sheenPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            palette.chipGlossRefined.withValues(alpha: 0.85),
            palette.chipGlossRefined.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(
          center: sheenCenter,
          radius: rect.width * 0.9,
        ));
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(rect.inflate(2), sheenPaint);
      canvas.restore();
    }

    // Glass highlight along the top edge.
    final highlightPaint = Paint()
      ..color = isRefined
          ? palette.chipGlossRefined.withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = isRefined ? 1.8 : 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final highlightPath = Path()
      ..moveTo(rect.left + (isRefined ? 9 : 6),
          rect.top + (isRefined ? 4 : 2))
      ..lineTo(rect.right - (isRefined ? 9 : 6),
          rect.top + (isRefined ? 4 : 2));
    canvas.drawPath(highlightPath, highlightPaint);

    canvas.drawRRect(rrect, borderPaint);

    // Subtle inner bevel that makes the refined edge read as glass.
    if (isRefined) {
      final inset = rect.deflate(1.5);
      final innerRRect = RRect.fromRectAndRadius(
        inset,
        Radius.circular(radius - 1.5),
      );
      canvas.drawRRect(
        innerRRect,
        Paint()
          ..color = palette.chipGlossRefined.withValues(
              alpha: 0.5)
          ..strokeWidth = 0.9
          ..style = PaintingStyle.stroke,
      );
    }

    // Notch indicator (small arc at top center)
    if (!isRefined) {
      final notchPaint = Paint()
        ..color = palette.chipBorderIndustrial
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      final notchRect = Rect.fromCenter(
        center: Offset(rect.center.dx, rect.top + 2),
        width: 20,
        height: 8,
      );
      canvas.drawArc(notchRect, 3.14, 3.14, false, notchPaint);
    }

    if (chip.definition.model == 'INPUT') {
      _drawInputSwitch(canvas, chip, rect);
    } else if (chip.definition.model == 'LED') {
      _drawLED(canvas, chip, rect);
    } else {
      // Model label (centered)
      final modelPainter = TextPainter(
        text: TextSpan(
          text: chip.definition.model,
          style: TextStyle(
            color: _chipAccentColor,
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
          style: TextStyle(
            color: _chipLabelSecondaryColor,
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
          rect.top + 44,
        ),
      );
    }

    // Draw each pin
    if (showPins) {
      _drawPins(canvas, chip);
    }
  }

  void _drawInputSwitch(Canvas canvas, ChipInstance chip, Rect rect) {
    final outputPins = chip.pinStates.values
        .where((p) => p.direction == PinDirection.output)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    for (final pin in outputPins) {
      final rowY = chip.pinPosition(pin.number).dy;
      final name = _inputPinName(chip, pin.number);
      final isHigh = pin.value == SignalState.high;

      final labelPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: _chipLabelSecondaryColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFamily: 'Segoe UI',
            fontFamilyFallback: const ['Microsoft YaHei UI', 'Roboto'],
            letterSpacing: 0.2,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(rect.left + 8, rowY - labelPainter.height / 2),
      );

      final trackRect = Rect.fromCenter(
        center: Offset(rect.center.dx + 2, rowY),
        width: 30,
        height: 10,
      );
      final trackPaint = Paint()
        ..color = isHigh
          ? palette.signalHigh.withValues(alpha: 0.25)
          : _chipLabelSecondaryColor.withValues(alpha: 0.3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(trackRect, const Radius.circular(5)),
        trackPaint,
      );

      final knobX = isHigh ? trackRect.right - 7 : trackRect.left + 7;
      canvas.drawCircle(
        Offset(knobX, rowY),
        6,
      Paint()
        ..color = isHigh ? palette.signalHigh : _chipLabelSecondaryColor,
      );
    }
  }

  String _inputPinName(ChipInstance chip, int pinNumber) {
    var number = 1;
    for (final candidate in circuit.chips) {
      if (candidate.definition.model != 'INPUT') continue;
      final pins = candidate.pinStates.values
          .where((p) => p.direction == PinDirection.output)
          .toList()
        ..sort((a, b) => a.number.compareTo(b.number));
      for (final pin in pins) {
        if (candidate.id == chip.id && pin.number == pinNumber) {
          return 'IN$number';
        }
        number++;
      }
    }
    return 'IN?';
  }

  void _drawLED(Canvas canvas, ChipInstance chip, Rect rect) {
    final input = chip.pinStates.values.firstWhere(
      (p) => p.direction == PinDirection.input,
      orElse: () => chip.pinStates.values.first,
    );
    final isLit = input.value == SignalState.high;
    final ledChips =
        circuit.chips.where((c) => c.definition.model == 'LED').toList();
    final ledIndex = ledChips.indexWhere((c) => c.id == chip.id);
    final ledName = 'LED${ledIndex + 1}';

    // Component label
    final labelPainter = TextPainter(
      text: TextSpan(
        text: ledName,
      style: TextStyle(
          color: _chipLabelSecondaryColor,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        fontFamily: 'Segoe UI',
        fontFamilyFallback: const ['Microsoft YaHei UI', 'Roboto'],
        letterSpacing: 0.2,
      ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(rect.center.dx - labelPainter.width / 2, rect.top + 10),
    );

    final bulbCenter = rect.center.translate(0, 6);

    // Bulb glow
    if (isLit) {
      canvas.drawCircle(
        bulbCenter,
        22,
      Paint()..color = palette.signalHigh.withValues(alpha: 0.18),
      );
    }

    // Bulb body
    canvas.drawCircle(
      bulbCenter,
      14,
      Paint()..color = isLit ? palette.signalHigh : palette.signalHighZ,
    );
    canvas.drawCircle(
      bulbCenter,
      14,
      Paint()
        ..color = palette.chipBorder
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
            ..color = palette.accent
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

      // Pin labels:
      // - Pin number: always shown, inside the chip body next to the pin dot.
      // - Function name: shown once the view is zoomed in enough, outside the
      //   chip but hugging the pin. Both are lifted above the pin so the
      //   horizontal wire lead-out at the pin's Y stays clear.
      final isLeft = pos.dx < chip.rect.center.dx;
      final showPinName = zoomScale >= _pinNameZoomThreshold;

      const labelGapX = 6.0; // horizontal gap from the pin dot edge
      const labelOffsetY = 8.0; // vertical lift above the pin center

      final numberPainter = TextPainter(
        text: TextSpan(
          text: '$pinNumber',
          style: TextStyle(
            color: _chipLabelColor,
            fontSize: 10,
            fontWeight: isPinSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final numberX = isLeft
          ? pos.dx + labelGapX
          : pos.dx - labelGapX - numberPainter.width;
      numberPainter.paint(
        canvas,
        Offset(numberX, pos.dy - labelOffsetY - numberPainter.height / 2),
      );

      if (showPinName && pinState.label.isNotEmpty) {
        final namePainter = TextPainter(
          text: TextSpan(
            text: pinState.label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w400,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();

        final nameX = isLeft
            ? pos.dx - labelGapX - namePainter.width
            : pos.dx + labelGapX;
        namePainter.paint(
          canvas,
          Offset(nameX, pos.dy - labelOffsetY - namePainter.height / 2),
        );
      }
    }
  }

  Color _pinColor(PinState pin) {
    switch (pin.direction) {
      case PinDirection.input:
        return palette.pinInput;
      case PinDirection.output:
        return palette.colorForSignal(pin.value);
      case PinDirection.power:
        return palette.pinPower;
      case PinDirection.ground:
        return palette.pinGround;
    }
  }
}
