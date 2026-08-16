import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS157 - Quad 2-to-1 Data Selector/Multiplexer, Non-Inverting (DIP-16).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///    S  1 |        | 16  VCC
///   1A  2 |        | 15  ~E
///   1B  3 |        | 14  4A
///   1Y  4 | 74LS157 | 13  4B
///   2A  5 |        | 12  4Y
///   2B  6 |        | 11  3A
///   2Y  7 |        | 10  3B
///  GND  8 |________| 9   3Y
/// ```
///
/// All four muxes share the select input S (pin 1) and the active-low
/// strobe ~E (pin 15). With ~E low, S selects the A or B input of each pair
/// and passes it to Y non-inverted; with ~E high every Y is forced low.
class Chip74LS157 extends ChipDefinition {
  @override
  String get model => '74LS157';

  @override
  String get description => '四组 2 选 1\n数据选择器\n非反相输出';

  @override
  String get functionSummary =>
      '四组 2 选 1 数据选择器，共用选择端 S 与低有效选通 ~E。~E 为低时工作：'
      'S 为低把 A 输入送到 Y、S 为高把 B 输入送到 Y（输出不反相）；'
      '~E 为高时 4 路输出全部为低电平。';

  @override
  int get propagationDelayPs => 9000; // ~9ns typical (data to output)

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: 'S', direction: PinDirection.input),
    PinDefinition(number: 2, label: '1A', direction: PinDirection.input),
    PinDefinition(number: 3, label: '1B', direction: PinDirection.input),
    PinDefinition(number: 4, label: '1Y', direction: PinDirection.output),
    PinDefinition(number: 5, label: '2A', direction: PinDirection.input),
    PinDefinition(number: 6, label: '2B', direction: PinDirection.input),
    PinDefinition(number: 7, label: '2Y', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: '~E', direction: PinDirection.input),
    PinDefinition(number: 14, label: '4A', direction: PinDirection.input),
    PinDefinition(number: 13, label: '4B', direction: PinDirection.input),
    PinDefinition(number: 12, label: '4Y', direction: PinDirection.output),
    PinDefinition(number: 11, label: '3A', direction: PinDirection.input),
    PinDefinition(number: 10, label: '3B', direction: PinDirection.input),
    PinDefinition(number: 9, label: '3Y', direction: PinDirection.output),
  ];

  static const _muxes = [
    (a: 2, b: 3, y: 4),
    (a: 5, b: 6, y: 7),
    (a: 11, b: 10, y: 9),
    (a: 14, b: 13, y: 12),
  ];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(name: '选择器 1', inputPins: [15, 1, 2, 3], outputPins: [4]),
        TruthTableGroup(name: '选择器 2', inputPins: [15, 1, 5, 6], outputPins: [7]),
        TruthTableGroup(name: '选择器 3', inputPins: [15, 1, 11, 10], outputPins: [9]),
        TruthTableGroup(name: '选择器 4', inputPins: [15, 1, 14, 13], outputPins: [12]),
      ];

  @override
  List<String> get datasheetNotes => const [
        '四组共用选择端 S 与选通 ~E，输出不反相。',
        '选通 ~E 为高时，4 路输出全部为低电平，与选择和数据无关。',
        'S 为低选 A 输入，S 为高选 B 输入。',
        '选通为低时：S 未知（X）或所选数据未知（X）→ 该组输出未知；任一输入悬空（Z）→ 该组输出未知。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final enable = _val(15, inputStates);
    final select = _val(1, inputStates);

    return {
      for (final mux in _muxes)
        mux.y: _evaluateMux(
          enable,
          select,
          _val(mux.a, inputStates),
          _val(mux.b, inputStates),
        ),
    };
  }

  static SignalState _evaluateMux(
    SignalState enable,
    SignalState select,
    SignalState a,
    SignalState b,
  ) {
    if ([enable, select, a, b].any((s) => s == SignalState.highZ)) {
      return SignalState.unknown;
    }
    if (enable == SignalState.unknown) return SignalState.unknown;
    if (enable == SignalState.high) return SignalState.low;
    if (select == SignalState.unknown) return SignalState.unknown;
    return select == SignalState.low ? a : b;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
