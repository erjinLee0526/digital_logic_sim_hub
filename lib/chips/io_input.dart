import 'package:flutter/painting.dart';

import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// A compact dual-input switch block.
///
/// Unlike 74-series logic chips, this component has no VCC/GND pins and
/// directly drives two output pins, IN1 and IN2, high or low.
class ChipInput extends ChipDefinition {
  @override
  String get model => 'INPUT';

  @override
  String get description => 'Dual Input Switch';

  @override
  int get propagationDelayPs => 0;

  @override
  double get width => 80;

  @override
  double get height => 80;

  @override
  List<PinDefinition> get pinDefinitions => const [
        PinDefinition(number: 1, label: 'IN1', direction: PinDirection.output),
        PinDefinition(number: 2, label: 'IN2', direction: PinDirection.output),
      ];

  @override
  Map<int, Offset> get pinRelativePositions => const {
        1: Offset(40, -16),
        2: Offset(40, 16),
      };

  @override
  Map<int, SignalState> evaluate(Map<int, SignalState> inputStates) {
    // Switches are driven by the user, not by logic evaluation.
    return const {};
  }
}
