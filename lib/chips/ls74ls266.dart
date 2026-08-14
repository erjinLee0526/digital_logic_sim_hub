import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS266 - Quad 2-Input XNOR (Exclusive-NOR) Gate, Open-Collector (DIP-14).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   1A  1 |        | 14  VCC
///   1B  2 |        | 13  4B
///   1Y  3 |74LS266 | 12  4A
///   2A  4 |        | 11  4Y
///   2B  5 |        | 10  3B
///   2Y  6 |        | 9   3A
///  GND  7 |________| 8   3Y
/// ```
///
/// Gate mapping:
///   Gate 1: 1A(1) + 1B(2) -> 1Y(3)
///   Gate 2: 2A(4) + 2B(5) -> 2Y(6)
///   Gate 3: 3A(9) + 3B(10) -> 3Y(8)
///   Gate 4: 4A(12) + 4B(13) -> 4Y(11)
///   Power: VCC(14), GND(7)
///
/// Open-collector outputs can only actively pull low. A logic-high result
/// leaves the output floating, so it is modeled as highZ (an external
/// pull-up resistor is required to obtain a driven high level).
class Chip74LS266 extends ChipDefinition {
  @override
  String get model => '74LS266';

  @override
  String get description => '4 路\n2 输入\n同或门（OC）';

  @override
  String get functionSummary =>
      '内含四个独立的 2 输入同或门，输出为集电极开路结构：两个输入电平'
      '不同时输出低电平，相同时输出悬空，需外接上拉电阻才能获得高电平。';

  @override
  int get propagationDelayPs => 18000; // ~18ns typical

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

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(name: '门 1', inputPins: [1, 2], outputPins: [3]),
        TruthTableGroup(name: '门 2', inputPins: [4, 5], outputPins: [6]),
        TruthTableGroup(name: '门 3', inputPins: [9, 10], outputPins: [8]),
        TruthTableGroup(name: '门 4', inputPins: [12, 13], outputPins: [11]),
      ];

  @override
  List<String> get datasheetNotes => const [
        '输出为集电极开路结构，只能主动拉低：逻辑 1 时输出悬空（显示为 '
            'Z），需外接上拉电阻才能得到驱动的高电平。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    return {
      // Gate 1: pins 1,2 -> pin 3
      3: _oc(_xnor(_val(1, inputStates), _val(2, inputStates))),
      // Gate 2: pins 4,5 -> pin 6
      6: _oc(_xnor(_val(4, inputStates), _val(5, inputStates))),
      // Gate 3: pins 9,10 -> pin 8
      8: _oc(_xnor(_val(9, inputStates), _val(10, inputStates))),
      // Gate 4: pins 12,13 -> pin 11
      11: _oc(_xnor(_val(12, inputStates), _val(13, inputStates))),
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }

  static SignalState _xnor(SignalState a, SignalState b) {
    return SignalState.xnor(a, b);
  }

  static SignalState _oc(SignalState level) {
    return level == SignalState.high ? SignalState.highZ : level;
  }
}
