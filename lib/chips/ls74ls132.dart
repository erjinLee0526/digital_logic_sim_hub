import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS132 - Quad 2-Input NAND Schmitt Trigger (DIP-14).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   1A  1 |        | 14  VCC
///   1B  2 |        | 13  4B
///   1Y  3 |        | 12  4A
///   2A  4 | 74LS132 | 11  4Y
///   2B  5 |        | 10  3B
///   2Y  6 |        | 9   3A
///  GND  7 |________| 8   3Y
/// ```
///
/// Four independent 2-input NAND gates with Schmitt-trigger inputs. The
/// analog hysteresis thresholds are not modeled, so each gate behaves as a
/// plain NAND gate.
class Chip74LS132 extends ChipDefinition {
  @override
  String get model => '74LS132';

  @override
  String get description => '四路 2 输入\n与非门\n施密特输入';

  @override
  String get functionSummary =>
      '四个独立的 2 输入与非门（施密特输入）：只有两个输入都为高电平时'
      '输出为低，否则输出为高。施密特触发的输入迟滞属于模拟特性，本四态'
      '数字仿真中未建模，按普通与非门处理。';

  @override
  int get propagationDelayPs => 15000; // ~15ns typical

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-7)
    PinDefinition(number: 1, label: '1A', direction: PinDirection.input),
    PinDefinition(number: 2, label: '1B', direction: PinDirection.input),
    PinDefinition(number: 3, label: '1Y', direction: PinDirection.output),
    PinDefinition(number: 4, label: '2A', direction: PinDirection.input),
    PinDefinition(number: 5, label: '2B', direction: PinDirection.input),
    PinDefinition(number: 6, label: '2Y', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 14-8)
    PinDefinition(number: 14, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 13, label: '4B', direction: PinDirection.input),
    PinDefinition(number: 12, label: '4A', direction: PinDirection.input),
    PinDefinition(number: 11, label: '4Y', direction: PinDirection.output),
    PinDefinition(number: 10, label: '3B', direction: PinDirection.input),
    PinDefinition(number: 9, label: '3A', direction: PinDirection.input),
    PinDefinition(number: 8, label: '3Y', direction: PinDirection.output),
  ];

  static const _gates = [
    (a: 1, b: 2, y: 3),
    (a: 4, b: 5, y: 6),
    (a: 9, b: 10, y: 8),
    (a: 12, b: 13, y: 11),
  ];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(name: '门 1', inputPins: [1, 2], outputPins: [3]),
        TruthTableGroup(name: '门 2', inputPins: [4, 5], outputPins: [6]),
        TruthTableGroup(name: '门 3', inputPins: [9, 10], outputPins: [8]),
        TruthTableGroup(name: '门 4', inputPins: [12, 13], outputPins: [11]),
      ];

  @override
  List<String> get datasheetNotes => const [
        '施密特触发的输入迟滞（滞回阈值）未建模，四态仿真中按普通与非门处理。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    return {
      for (final gate in _gates)
        gate.y: SignalState.nand(
          _val(gate.a, inputStates),
          _val(gate.b, inputStates),
        ),
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
