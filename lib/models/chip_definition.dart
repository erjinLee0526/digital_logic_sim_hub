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

  /// Natural-language summary of what the chip does, shown in the chip
  /// manual. Falls back to [description] when not overridden.
  String get functionSummary => description;

  /// Typical propagation delay in picoseconds.
  /// 74LS00 is ~10ns = 10000ps.
  int get propagationDelayPs;

  /// Visual size of the chip rectangle in circuit units.
  double get width;
  double get height;

  /// The list of pin definitions (template pins w/o state).
  List<PinDefinition> get pinDefinitions;

  /// Initial values for the chip's internal, non-pin state.
  ///
  /// Stateful chips such as edge-triggered flip-flops need to remember
  /// things like the previous clock value between evaluations. This map is
  /// copied per chip instance and mutated by [evaluate].
  Map<String, SignalState> get initialState => const {};

  /// Named groups of pins that form one logic function (e.g. "Gate 1").
  ///
  /// The graphical chip manual renders one truth table per group by
  /// enumerating the driven input levels through [evaluate]. Stateful chips
  /// (flip-flops, counters, ...) leave this empty.
  List<TruthTableGroup> get truthTableGroups => const [];

  /// Optional datasheet notes shown in the chip manual, e.g. open-collector
  /// output behavior that needs an external pull-up.
  List<String> get datasheetNotes => const [];

  /// Whether this chip matches a library-search query.
  ///
  /// Matches the model number only (e.g. "74LS03"), never the description.
  /// This keeps searches such as "3" from matching chips whose description
  /// merely mentions "3 输入" or "三路".
  bool matchesSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return model.toLowerCase().contains(q);
  }

  /// Evaluates the chip output for all output pins.
  /// [inputStates] maps pin number → current signal state.
  /// [internalState] holds the instance's mutable internal state; it must
  /// not be shared between chip instances.
  /// Returns a map of pin number → new signal state (only output pins).
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  });

  /// Returns the relative position of each pin on the chip rectangle.
  /// DIP pins are arranged 1..perSide on the left and maxPin..perSide+1
  /// on the right, with a pitch of one grid unit. Position is relative
  /// to the chip center.
  Map<int, Offset> get pinRelativePositions => _computePinPositions();

  Map<int, Offset> _computePinPositions() {
    final map = <int, Offset>{};
    final halfW = width / 2;
    final maxPin =
        pinDefinitions.map((pin) => pin.number).reduce((a, b) => a > b ? a : b);
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

/// Describes one logic function inside a chip: a display name plus the pin
/// numbers of its inputs and outputs (in column order).
class TruthTableGroup {
  /// Human-readable name, e.g. "Gate 1".
  final String name;

  /// Input pin numbers in the order they appear as truth-table columns.
  final List<int> inputPins;

  /// Output pin numbers in the order they appear as truth-table columns.
  final List<int> outputPins;

  const TruthTableGroup({
    required this.name,
    required this.inputPins,
    required this.outputPins,
  });
}
