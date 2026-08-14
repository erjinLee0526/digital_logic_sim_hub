import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS02 - Quad 2-Input NOR Gate (DIP-14).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   1Y  1 |        | 14  VCC
///   1A  2 |        | 13  4Y
///   1B  3 | 74LS02 | 12  4B
///   2Y  4 |        | 11  4A
///   2A  5 |        | 10  3Y
///   2B  6 |        | 9   3B
///  GND  7 |________| 8   3A
/// ```
///
/// Gate mapping:
///   Gate 1: 1A(2) + 1B(3) -> 1Y(1)
///   Gate 2: 2A(5) + 2B(6) -> 2Y(4)
///   Gate 3: 3A(8) + 3B(9) -> 3Y(10)
///   Gate 4: 4A(11) + 4B(12) -> 4Y(13)
///   Power: VCC(14), GND(7)
class Chip74LS02 extends ChipDefinition {
  @override
  String get model => '74LS02';

  @override
  String get description => '4 路\n2 输入\n或非门';

  @override
  String get functionSummary =>
      '内含四个独立的 2 输入或非门：只有当两个输入都为低电平时，输出才为'
      '高电平；任意一个输入为高电平，输出即为低电平。';

  @override
  int get propagationDelayPs => 10000; // ~10ns typical

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-7)
    PinDefinition(number: 1, label: '1Y', direction: PinDirection.output),
    PinDefinition(number: 2, label: '1A', direction: PinDirection.input),
    PinDefinition(number: 3, label: '1B', direction: PinDirection.input),
    PinDefinition(number: 4, label: '2Y', direction: PinDirection.output),
    PinDefinition(number: 5, label: '2A', direction: PinDirection.input),
    PinDefinition(number: 6, label: '2B', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 14-8)
    PinDefinition(number: 14, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 13, label: '4Y', direction: PinDirection.output),
    PinDefinition(number: 12, label: '4B', direction: PinDirection.input),
    PinDefinition(number: 11, label: '4A', direction: PinDirection.input),
    PinDefinition(number: 10, label: '3Y', direction: PinDirection.output),
    PinDefinition(number: 9, label: '3B', direction: PinDirection.input),
    PinDefinition(number: 8, label: '3A', direction: PinDirection.input),
  ];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(name: '门 1', inputPins: [2, 3], outputPins: [1]),
        TruthTableGroup(name: '门 2', inputPins: [5, 6], outputPins: [4]),
        TruthTableGroup(name: '门 3', inputPins: [8, 9], outputPins: [10]),
        TruthTableGroup(name: '门 4', inputPins: [11, 12], outputPins: [13]),
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    return {
      // Gate 1: pins 2,3 -> pin 1
      1: _nor(_val(2, inputStates), _val(3, inputStates)),
      // Gate 2: pins 5,6 -> pin 4
      4: _nor(_val(5, inputStates), _val(6, inputStates)),
      // Gate 3: pins 8,9 -> pin 10
      10: _nor(_val(8, inputStates), _val(9, inputStates)),
      // Gate 4: pins 11,12 -> pin 13
      13: _nor(_val(11, inputStates), _val(12, inputStates)),
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }

  static SignalState _nor(SignalState a, SignalState b) {
    return SignalState.nor(a, b);
  }
}
