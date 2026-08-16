import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS14 - Hex Schmitt-Trigger Inverter (DIP-14).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   1A  1 |        | 14  VCC
///   1Y  2 |        | 13  6A
///   2A  3 | 74LS14 | 12  6Y
///   2Y  4 |        | 11  5A
///   3A  5 |        | 10  5Y
///   3Y  6 |        | 9   4A
///  GND  7 |________| 8   4Y
/// ```
///
/// Six independent inverters with Schmitt-trigger inputs. The analog
/// hysteresis thresholds are not modeled in this four-state simulator, so
/// each gate behaves as a plain inverter.
class Chip74LS14 extends ChipDefinition {
  @override
  String get model => '74LS14';

  @override
  String get description => '六反相器\n施密特输入';

  @override
  String get functionSummary =>
      '六个独立的施密特反相器：输出是输入的反相。施密特触发的输入迟滞'
      '（两个不同的翻转阈值）属于模拟特性，本四态数字仿真中未建模，'
      '按普通反相器处理。';

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
    PinDefinition(number: 2, label: '1Y', direction: PinDirection.output),
    PinDefinition(number: 3, label: '2A', direction: PinDirection.input),
    PinDefinition(number: 4, label: '2Y', direction: PinDirection.output),
    PinDefinition(number: 5, label: '3A', direction: PinDirection.input),
    PinDefinition(number: 6, label: '3Y', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 14-8)
    PinDefinition(number: 14, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 13, label: '6A', direction: PinDirection.input),
    PinDefinition(number: 12, label: '6Y', direction: PinDirection.output),
    PinDefinition(number: 11, label: '5A', direction: PinDirection.input),
    PinDefinition(number: 10, label: '5Y', direction: PinDirection.output),
    PinDefinition(number: 9, label: '4A', direction: PinDirection.input),
    PinDefinition(number: 8, label: '4Y', direction: PinDirection.output),
  ];

  static const _gates = [
    (a: 1, y: 2),
    (a: 3, y: 4),
    (a: 5, y: 6),
    (a: 9, y: 8),
    (a: 11, y: 10),
    (a: 13, y: 12),
  ];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(name: '反相器 1', inputPins: [1], outputPins: [2]),
        TruthTableGroup(name: '反相器 2', inputPins: [3], outputPins: [4]),
        TruthTableGroup(name: '反相器 3', inputPins: [5], outputPins: [6]),
        TruthTableGroup(name: '反相器 4', inputPins: [9], outputPins: [8]),
        TruthTableGroup(name: '反相器 5', inputPins: [11], outputPins: [10]),
        TruthTableGroup(name: '反相器 6', inputPins: [13], outputPins: [12]),
      ];

  @override
  List<String> get datasheetNotes => const [
        '施密特触发的输入迟滞（滞回阈值）未建模，四态仿真中按普通反相器处理。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    return {
      for (final gate in _gates)
        gate.y: _val(gate.a, inputStates).not(),
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
