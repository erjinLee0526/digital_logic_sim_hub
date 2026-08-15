import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/circuit.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';
import '../providers/circuit_provider.dart';
import '../providers/editor_provider.dart';
import '../providers/simulation_provider.dart';
import '../theme/app_theme.dart';
import '../canvas/hit_test.dart';
import '../canvas/circuit_painter.dart';

/// The main circuit editing canvas with zoom, pan, and gesture handling.
///
/// Gesture architecture:
/// - InteractiveViewer handles zoom (pinch/scroll) and pan (drag empty space).
/// - Inner GestureDetector handles taps (wiring/select/delete) and long-press
///   (chip dragging). Long-press has its own gesture recognizer that doesn't
///   conflict with InteractiveViewer's pan recognizer.
/// - Listener tracks the pointer position for ghost-wire rendering.
class CircuitCanvas extends ConsumerStatefulWidget {
  const CircuitCanvas({super.key});

  @override
  ConsumerState<CircuitCanvas> createState() => _CircuitCanvasState();
}

class _CircuitCanvasState extends ConsumerState<CircuitCanvas> {
  final TransformationController _transformController =
      TransformationController();

  String? _draggedChipId; // non-null when dragging a chip

  @override
  void initState() {
    super.initState();
    // Rebuild when the zoom changes so the painter can switch between
    // number-only and number+name pin labels.
    _transformController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    final circuit = ref.watch(circuitProvider);
    final tool = ref.watch(editorToolProvider);
    final chipStyle = ref.watch(chipStyleProvider);
    final showPins = ref.watch(showPinsProvider);
    final selectedPinId = ref.watch(selectedPinProvider);
    final selectedChipId = ref.watch(selectedChipProvider);
    final selectedWireId = ref.watch(selectedWireProvider);
    final mousePos = ref.watch(mouseCircuitPositionProvider);
    final zoomScale = _transformController.value.getMaxScaleOnAxis();

    // Calculate ghost wire endpoints
    Offset? ghostStart;
    Offset? ghostEnd;
    if (selectedPinId != null && mousePos != null) {
      // Find pin position
      for (final chip in circuit.chips) {
        for (final entry in chip.pinAbsolutePositions.entries) {
          if (chip.pinId(entry.key) == selectedPinId) {
            ghostStart = entry.value;
            break;
          }
        }
        if (ghostStart != null) break;
      }
      // If the pin already has wires, ghost wire starts from the branch point
      if (ghostStart != null) {
        final branchPoint = computeWireBranchPoint(selectedPinId, circuit,
            requireMultipleWires: false);
        if (branchPoint != null) {
          ghostStart = branchPoint;
        }
      }
      ghostEnd = mousePos;
    }

    return InteractiveViewer(
      transformationController: _transformController,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.1,
      maxScale: 5.0,
      panEnabled: tool != EditorTool.dragging,
      constrained: false,
      child: GestureDetector(
        // Taps → wiring / selecting / deleting
        onTapUp: (details) => _handleTap(details.localPosition, circuit),

        // Long-press → chip dragging (doesn't conflict with
        // InteractiveViewer's pan gesture)
        onLongPressStart: (details) =>
            _handleLongPressStart(details.localPosition, circuit),
        onLongPressMoveUpdate: (details) =>
            _handleLongPressMoveUpdate(details.localPosition, circuit),
        onLongPressEnd: (_) => _handleLongPressEnd(),

        child: Listener(
          // Track pointer position for ghost wire
          onPointerMove: (event) => _updateMousePos(event.localPosition),
          child: CustomPaint(
            painter: CircuitPainter(
              circuit: circuit,
              palette: palette,
              chipStyle: chipStyle,
              showPins: showPins,
              selectedPinId: selectedPinId,
              selectedChipId: selectedChipId,
              selectedWireId: selectedWireId,
              ghostWireStart: ghostStart,
              ghostWireEnd: ghostEnd,
              zoomScale: zoomScale,
            ),
            size: const Size(10000, 10000),
          ),
        ),
      ),
    );
  }

  // ── Pointer tracking ──────────────────────────────────────────

  void _updateMousePos(Offset localPos) {
    ref.read(mouseCircuitPositionProvider.notifier).state = localPos;
  }

  // ── Tap handling ───────────────────────────────────────────────

  void _handleTap(Offset localPos, Circuit circuit) {
    final tool = ref.read(editorToolProvider);
    final hit = hitTest(localPos, circuit);

    switch (tool) {
      case EditorTool.wiring:
        _handleWiringTap(hit);
      case EditorTool.dragging:
        _handleSelectTap(hit);
      case EditorTool.deleting:
        _handleDeleteTap(hit, circuit);
    }
  }

  void _handleWiringTap(HitTestResult hit) {
    final currentSelectedPin = ref.read(selectedPinProvider);

    if (hit.target == HitTarget.pin && hit.pinId != null) {
      if (currentSelectedPin == null) {
        // First pin selected → highlight it
        ref.read(selectedPinProvider.notifier).state = hit.pinId;
        ref.read(selectedChipProvider.notifier).state = null;
        ref.read(selectedWireProvider.notifier).state = null;
      } else if (currentSelectedPin == hit.pinId) {
        // Same pin → deselect
        ref.read(selectedPinProvider.notifier).state = null;
      } else {
        // Second pin → create wire
        ref
            .read(circuitProvider.notifier)
            .addWire(currentSelectedPin, hit.pinId!);
        ref.read(selectedPinProvider.notifier).state = null;
      }
    } else if (hit.target == HitTarget.chipBody && hit.chipId != null) {
      final chip = ref.read(circuitProvider).chipById(hit.chipId!);
      if (chip?.definition.model == 'INPUT') {
        _toggleInputSwitch(hit.chipId!, hit.circuitPoint);
        return;
      }
      ref.read(selectedChipProvider.notifier).state = hit.chipId;
      ref.read(selectedPinProvider.notifier).state = null;
      ref.read(selectedWireProvider.notifier).state = null;
    } else if (hit.target == HitTarget.wire && hit.wireId != null) {
      ref.read(selectedWireProvider.notifier).state = hit.wireId;
      ref.read(selectedPinProvider.notifier).state = null;
      ref.read(selectedChipProvider.notifier).state = null;
    } else {
      // Empty space → clear all selections
      ref.read(selectedPinProvider.notifier).state = null;
      ref.read(selectedChipProvider.notifier).state = null;
      ref.read(selectedWireProvider.notifier).state = null;
    }
  }

  void _toggleInputSwitch(String chipId, Offset point) {
    final circuit = ref.read(circuitProvider);
    final chip = circuit.chipById(chipId);
    if (chip == null) return;

    final outputPins = chip.pinStates.values
        .where((p) => p.direction == PinDirection.output)
        .toList();
    if (outputPins.isEmpty) return;

    final switchPin = outputPins.reduce((a, b) {
      final aDistance = (chip.pinPosition(a.number).dy - point.dy).abs();
      final bDistance = (chip.pinPosition(b.number).dy - point.dy).abs();
      return aDistance <= bDistance ? a : b;
    });
    final engine = ref.read(simulationEngineProvider);

    engine.rebuild(circuit);
    final newValue = switchPin.value == SignalState.high
        ? SignalState.low
        : SignalState.high;
    engine.injectSignal(chip.pinId(switchPin.number), newValue);
    engine.runUntilStable();

    ref.read(circuitProvider.notifier).forceUpdate();
    ref.read(selectedPinProvider.notifier).state = null;
  }

  void _handleSelectTap(HitTestResult hit) {
    if (hit.target == HitTarget.chipBody && hit.chipId != null) {
      ref.read(selectedChipProvider.notifier).state = hit.chipId;
    } else {
      ref.read(selectedChipProvider.notifier).state = null;
    }
    ref.read(selectedPinProvider.notifier).state = null;
    ref.read(selectedWireProvider.notifier).state = null;
  }

  void _handleDeleteTap(HitTestResult hit, Circuit circuit) {
    if (hit.target == HitTarget.wire && hit.wireId != null) {
      ref.read(circuitProvider.notifier).removeWire(hit.wireId!);
      ref.read(selectedWireProvider.notifier).state = null;
    } else if (hit.target == HitTarget.chipBody && hit.chipId != null) {
      ref.read(circuitProvider.notifier).removeChip(hit.chipId!);
      ref.read(selectedChipProvider.notifier).state = null;
    } else if (hit.target == HitTarget.pin && hit.pinId != null) {
      ref.read(circuitProvider.notifier).removeWiresForPin(hit.pinId!);
    }
  }

  // ── Chip dragging (long-press in drag mode) ────────────────────

  void _handleLongPressStart(Offset localPos, Circuit circuit) {
    final tool = ref.read(editorToolProvider);
    if (tool != EditorTool.dragging) return;

    final hit = hitTest(localPos, circuit);

    if (hit.target == HitTarget.chipBody && hit.chipId != null) {
      setState(() => _draggedChipId = hit.chipId);
      ref.read(selectedChipProvider.notifier).state = hit.chipId;
      // Give haptic feedback on supported platforms
      HapticFeedback.lightImpact();
    }
  }

  void _handleLongPressMoveUpdate(Offset localPos, Circuit circuit) {
    if (_draggedChipId == null) return;

    final chip = circuit.chipById(_draggedChipId!);
    if (chip == null) return;

    ref.read(circuitProvider.notifier).moveChip(_draggedChipId!, localPos);
  }

  void _handleLongPressEnd() {
    _draggedChipId = null;
  }
}
