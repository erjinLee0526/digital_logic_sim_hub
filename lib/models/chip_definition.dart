import 'package:flutter/painting.dart';
import 'pin.dart';
import 'signal_state.dart';

/// Defines a chip type (e.g. 74LS00) — the blueprint.
/// Each concrete chip class extends this and provides pin layout + logic.
abstract class ChipDefinition {
  /// Chip model number, e.g. "74LS00".
  String get model;

  /// Human-readable description, e.g. "Quad 2-Input NAND Gate".
  String get description;

  /// Typical propagation delay in picoseconds.
  /// 74LS00 is ~10ns = 10000ps.
  int get propagationDelayPs;

  /// Visual size of the chip rectangle in circuit units.
  double get width;
  double get height;

  /// The list of pin definitions (template pins w/o state).
  List<PinDefinition> get pinDefinitions;

  /// Evaluates the chip output for all output pins.
  /// [inputStates] maps pin number → current signal state.
  /// Returns a map of pin number → new signal state (only output pins).
  Map<int, SignalState> evaluate(Map<int, SignalState> inputStates);

  /// Returns the relative position of each pin on the chip rectangle.
  /// Pin 1–7 on left side, pin 14–8 on right side (standard DIP layout).
  /// Position is relative to chip center.
  Map<int, Offset> get pinRelativePositions => _computePinPositions();

  Map<int, Offset> _computePinPositions() {
    final map = <int, Offset>{};
    final halfW = width / 2;
    final spacing = height / 7; // 7 positions per side
    final topY = -height / 2;

    for (final pin in pinDefinitions) {
      final num = pin.number;
      if (num <= 7) {
        // Left side: pins 1–7
        map[num] = Offset(-halfW, topY + spacing * (num - 0.5));
      } else {
        // Right side: pins 14–8 (14 at top, 8 near bottom)
        map[num] = Offset(halfW, topY + spacing * (14 - num + 0.5));
      }
    }
    return map;
  }
}
