import 'package:flutter/painting.dart';

import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// A user-controlled input switch.
///
/// Unlike 74-series logic chips, this component has no VCC/GND pins and
/// simply drives its single output pin to high or low.
class ChipInput extends ChipDefinition {
  @override
  String get model => 'INPUT';

  @override
  String get description => 'Input Switch';

  @override
  int get propagationDelayPs => 0;

  @override
  double get width => 80;

  @override
  double get height => 80;

  @override
  List<PinDefinition> get pinDefinitions => const [
        PinDefinition(number: 1, label: 'OUT', direction: PinDirection.output),
      ];

  @override
  Map<int, Offset> get pinRelativePositions => const {
        1: Offset(40, 0),
      };

  @override
  Map<int, SignalState> evaluate(Map<int, SignalState> inputStates) {
    // Switches are driven by the user, not by logic evaluation.
    return const {};
  }
}
