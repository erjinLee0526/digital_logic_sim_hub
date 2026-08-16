import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS27 - Triple 3-Input NOR Gate (DIP-14).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   1A  1 |        | 14  VCC
///   1B  2 |        | 13  1C
///   2A  3 | 74LS27 | 12  1Y
///   2B  4 |        | 11  3C
///   2C  5 |        | 10  3B
///   2Y  6 |        | 9   3A
///  GND  7 |________| 8   3Y
/// ```
///
/// Gate mapping:
///   Gate 1: 1A(1) + 1B(2) + 1C(13) -> 1Y(12)
///   Gate 2: 2A(3) + 2B(4) + 2C(5)  -> 2Y(6)
///   Gate 3: 3A(9) + 3B(10) + 3C(11) -> 3Y(8)
///   Power: VCC(14), GND(7)
class Chip74LS27 extends ChipDefinition {
  @override
  String get model => '74LS27';

  @override
  String get description => '3 路\n3 输入\n或非门';

  @override
  String get functionSummary =>
      '内含三个独立的 3 输入或非门：只有当三个输入都为低电平时，输出才为'
      '高电平；任意输入为高电平，输出即为低电平。';

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
    PinDefinition(number: 1, label: '1A', direction: PinDirection.input),
    PinDefinition(number: 2, label: '1B', direction: PinDirection.input),
    PinDefinition(number: 3, label: '2A', direction: PinDirection.input),
    PinDefinition(number: 4, label: '2B', direction: PinDirection.input),
    PinDefinition(number: 5, label: '2C', direction: PinDirection.input),
    PinDefinition(number: 6, label: '2Y', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 14-8)
    PinDefinition(number: 14, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 13, label: '1C', direction: PinDirection.input),
    PinDefinition(number: 12, label: '1Y', direction: PinDirection.output),
    PinDefinition(number: 11, label: '3C', direction: PinDirection.input),
    PinDefinition(number: 10, label: '3B', direction: PinDirection.input),
    PinDefinition(number: 9, label: '3A', direction: PinDirection.input),
    PinDefinition(number: 8, label: '3Y', direction: PinDirection.output),
  ];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(name: '门 1', inputPins: [1, 2, 13], outputPins: [12]),
        TruthTableGroup(name: '门 2', inputPins: [3, 4, 5], outputPins: [6]),
        TruthTableGroup(name: '门 3', inputPins: [9, 10, 11], outputPins: [8]),
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    return {
      // Gate 1: pins 1,2,13 -> pin 12
      12: _nor3(
          _val(1, inputStates), _val(2, inputStates), _val(13, inputStates)),
      // Gate 2: pins 3,4,5 -> pin 6
      6: _nor3(
          _val(3, inputStates), _val(4, inputStates), _val(5, inputStates)),
      // Gate 3: pins 9,10,11 -> pin 8
      8: _nor3(
          _val(9, inputStates), _val(10, inputStates), _val(11, inputStates)),
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }

  static SignalState _nor3(SignalState a, SignalState b, SignalState c) {
    return SignalState.nor3(a, b, c);
  }
}
