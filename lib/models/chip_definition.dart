import 'package:flutter/painting.dart';
import 'circuit_grid.dart';
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
  /// DIP pins are arranged 1..perSide on the left and maxPin..perSide+1
  /// on the right, with a pitch of one grid unit. Position is relative
  /// to the chip center.
  Map<int, Offset> get pinRelativePositions => _computePinPositions();

  Map<int, Offset> _computePinPositions() {
    final map = <int, Offset>{};
    final halfW = width / 2;
    final maxPin = pinDefinitions.map((pin) => pin.number).reduce((a, b) => a > b ? a : b);
    final perSide = maxPin ~/ 2;
    final pitch = kGridUnit;
    final topY = -(perSide - 1) * pitch / 2;

    for (final pin in pinDefinitions) {
      final num = pin.number;
      if (num <= perSide) {
        // Left side: pins 1..perSide
        map[num] = Offset(-halfW, topY + pitch * (num - 1));
      } else {
        // Right side: pins maxPin down to perSide + 1
        map[num] = Offset(halfW, topY + pitch * (maxPin - num));
      }
    }
    return map;
  }
}
