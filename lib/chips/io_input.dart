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
  String get description => '双路输入开关';

  @override
  String get functionSummary =>
      '手动输入器件，可分别将 IN1、IN2 两个输出引脚直接驱动为高电平或'
      '低电平，用于向电路提供 0/1 信号。';

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
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    // Switches are driven by the user, not by logic evaluation.
    return const {};
  }
}
