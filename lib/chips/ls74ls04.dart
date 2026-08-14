import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS04 - Hex Inverter (DIP-14).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   1A  1 |        | 14  VCC
///   1Y  2 |        | 13  6A
///   2A  3 | 74LS04 | 12  6Y
///   2Y  4 |        | 11  5A
///   3A  5 |        | 10  5Y
///   3Y  6 |        | 9   4A
///  GND  7 |________| 8   4Y
/// ```
///
/// Gate mapping:
///   Gate 1: 1A(1) -> 1Y(2)
///   Gate 2: 2A(3) -> 2Y(4)
///   Gate 3: 3A(5) -> 3Y(6)
///   Gate 4: 4A(9) -> 4Y(8)
///   Gate 5: 5A(11) -> 5Y(10)
///   Gate 6: 6A(13) -> 6Y(12)
///   Power: VCC(14), GND(7)
class Chip74LS04 extends ChipDefinition {
  @override
  String get model => '74LS04';

  @override
  String get description => '6 路\n1 输入\n反相器';

  @override
  String get functionSummary =>
      '内含六个独立的反相器（非门）：每个门的输出电平始终与其输入电平'
      '相反。';

  @override
  int get propagationDelayPs => 9500; // ~9.5ns typical

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

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(name: '门 1', inputPins: [1], outputPins: [2]),
        TruthTableGroup(name: '门 2', inputPins: [3], outputPins: [4]),
        TruthTableGroup(name: '门 3', inputPins: [5], outputPins: [6]),
        TruthTableGroup(name: '门 4', inputPins: [9], outputPins: [8]),
        TruthTableGroup(name: '门 5', inputPins: [11], outputPins: [10]),
        TruthTableGroup(name: '门 6', inputPins: [13], outputPins: [12]),
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    return {
      // Gate 1: pin 1 -> pin 2
      2: _invert(_val(1, inputStates)),
      // Gate 2: pin 3 -> pin 4
      4: _invert(_val(3, inputStates)),
      // Gate 3: pin 5 -> pin 6
      6: _invert(_val(5, inputStates)),
      // Gate 4: pin 9 -> pin 8
      8: _invert(_val(9, inputStates)),
      // Gate 5: pin 11 -> pin 10
      10: _invert(_val(11, inputStates)),
      // Gate 6: pin 13 -> pin 12
      12: _invert(_val(13, inputStates)),
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }

  static SignalState _invert(SignalState a) {
    return SignalState.invert(a);
  }
}
