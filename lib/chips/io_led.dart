import 'package:flutter/painting.dart';

import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// A single-input LED indicator.
///
/// The LED is dark when its input is low and lit when its input is high.
/// It has no VCC/GND pins; the input pin is directly connected.
class ChipLED extends ChipDefinition {
  @override
  String get model => 'LED';

  @override
  String get description => 'Output LED';

  @override
  int get propagationDelayPs => 0;

  @override
  double get width => 80;

  @override
  double get height => 80;

  @override
  List<PinDefinition> get pinDefinitions => const [
        PinDefinition(number: 1, label: 'IN', direction: PinDirection.input),
      ];

  @override
  Map<int, Offset> get pinRelativePositions => const {
        1: Offset(-40, 0),
      };

  @override
  Map<int, SignalState> evaluate(Map<int, SignalState> inputStates) {
    // LEDs only observe their input; they do not produce logic outputs.
    return const {};
  }
}
