import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS21 - Dual 4-Input AND Gate (DIP-14).
///
/// Pins 3 and 11 are NC (no connection) on the real package; they are not
/// modeled as pins.
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   1A  1 |        | 14  VCC
///   1B  2 |        | 13  2D
///   NC  3 |        | 12  2C
///   1C  4 | 74LS21 | 11  NC
///   1D  5 |        | 10  2B
///   1Y  6 |        | 9   2A
///  GND  7 |________| 8   2Y
/// ```
///
/// Gate mapping:
///   Gate 1: 1A(1) + 1B(2) + 1C(4) + 1D(5) -> 1Y(6)
///   Gate 2: 2A(9) + 2B(10) + 2C(12) + 2D(13) -> 2Y(8)
///   Power: VCC(14), GND(7)
class Chip74LS21 extends ChipDefinition {
  @override
  String get model => '74LS21';

  @override
  String get description => '2 路\n4 输入\n与门';

  @override
  String get functionSummary =>
      '内含两个独立的 4 输入与门：只有当四个输入都为高电平时，输出才为'
      '高电平；任意输入为低电平，输出即为低电平。';

  @override
  int get propagationDelayPs => 20000; // max 20ns (TI datasheet)

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-7; pin 3 is NC and omitted)
    PinDefinition(number: 1, label: '1A', direction: PinDirection.input),
    PinDefinition(number: 2, label: '1B', direction: PinDirection.input),
    PinDefinition(number: 4, label: '1C', direction: PinDirection.input),
    PinDefinition(number: 5, label: '1D', direction: PinDirection.input),
    PinDefinition(number: 6, label: '1Y', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 14-8; pin 11 is NC and omitted)
    PinDefinition(number: 14, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 13, label: '2D', direction: PinDirection.input),
    PinDefinition(number: 12, label: '2C', direction: PinDirection.input),
    PinDefinition(number: 10, label: '2B', direction: PinDirection.input),
    PinDefinition(number: 9, label: '2A', direction: PinDirection.input),
    PinDefinition(number: 8, label: '2Y', direction: PinDirection.output),
  ];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(
            name: '门 1', inputPins: [1, 2, 4, 5], outputPins: [6]),
        TruthTableGroup(
            name: '门 2', inputPins: [9, 10, 12, 13], outputPins: [8]),
      ];

  @override
  List<String> get datasheetNotes => const [
        '3 脚与 11 脚为 NC（空脚），无内部连接，仿真中未建模。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    return {
      // Gate 1: pins 1,2,4,5 -> pin 6
      6: _and4(_val(1, inputStates), _val(2, inputStates),
          _val(4, inputStates), _val(5, inputStates)),
      // Gate 2: pins 9,10,12,13 -> pin 8
      8: _and4(_val(9, inputStates), _val(10, inputStates),
          _val(12, inputStates), _val(13, inputStates)),
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }

  static SignalState _and4(
      SignalState a, SignalState b, SignalState c, SignalState d) {
    return SignalState.and4(a, b, c, d);
  }
}
