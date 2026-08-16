import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS153 - Dual 4-to-1 Data Selector/Multiplexer, Active-Low Strobes (DIP-16).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///  ~1G  1 |        | 16  VCC
///    B  2 |        | 15  ~2G
///  1C3  3 |        | 14  A
///  1C2  4 | 74LS153 | 13  2C3
///  1C1  5 |        | 12  2C2
///  1C0  6 |        | 11  2C1
///   1Y  7 |        | 10  2C0
///  GND  8 |________| 9   2Y
/// ```
///
/// Both muxes share the select inputs A (LSB, pin 14) and B (MSB, pin 2).
/// Each half has its own active-low strobe ~G: while high its Y is forced
/// low; while low, Y follows the C input selected by (B A).
class Chip74LS153 extends ChipDefinition {
  @override
  String get model => '74LS153';

  @override
  String get description => '双 4 选 1\n数据选择器\n独立选通';

  @override
  String get functionSummary =>
      '内含两个 4 选 1 数据选择器，共用两位地址（A 为低位、B 为高位）。'
      '每组选通 ~G 为低时工作：按地址从 C0–C3 中选出一路送到本组输出 Y；'
      '~G 为高时该组输出固定为低电平。';

  @override
  int get propagationDelayPs => 14000; // ~14ns typical (data to output)

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: '~1G', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'B', direction: PinDirection.input),
    PinDefinition(number: 3, label: '1C3', direction: PinDirection.input),
    PinDefinition(number: 4, label: '1C2', direction: PinDirection.input),
    PinDefinition(number: 5, label: '1C1', direction: PinDirection.input),
    PinDefinition(number: 6, label: '1C0', direction: PinDirection.input),
    PinDefinition(number: 7, label: '1Y', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: '~2G', direction: PinDirection.input),
    PinDefinition(number: 14, label: 'A', direction: PinDirection.input),
    PinDefinition(number: 13, label: '2C3', direction: PinDirection.input),
    PinDefinition(number: 12, label: '2C2', direction: PinDirection.input),
    PinDefinition(number: 11, label: '2C1', direction: PinDirection.input),
    PinDefinition(number: 10, label: '2C0', direction: PinDirection.input),
    PinDefinition(number: 9, label: '2Y', direction: PinDirection.output),
  ];

  static const _half1Data = [6, 5, 4, 3]; // 1C0..1C3
  static const _half2Data = [10, 11, 12, 13]; // 2C0..2C3

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(
          name: '数据选择器 1',
          inputPins: [1, 2, 14, 6, 5, 4, 3],
          outputPins: [7],
        ),
        TruthTableGroup(
          name: '数据选择器 2',
          inputPins: [15, 2, 14, 10, 11, 12, 13],
          outputPins: [9],
        ),
      ];

  @override
  List<String> get datasheetNotes => const [
        '两组选择器共用地址 A/B（B 为高位、A 为低位），各自拥有独立的低有效选通 ~G。',
        '选通 ~G 为高时，该组输出固定为 0，与地址和数据无关。',
        '选通 ~G 为低时：地址未知（X）或所选数据未知（X）→ 该组输出未知；任一输入悬空（Z）→ 该组输出未知。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    return {
      ..._evaluateMux(inputStates,
          enablePin: 1, dataPins: _half1Data, yPin: 7),
      ..._evaluateMux(inputStates,
          enablePin: 15, dataPins: _half2Data, yPin: 9),
    };
  }

  Map<int, SignalState> _evaluateMux(
    Map<int, SignalState> states, {
    required int enablePin,
    required List<int> dataPins,
    required int yPin,
  }) {
    final enable = _val(enablePin, states);
    final a = _val(14, states);
    final b = _val(2, states);
    final data = [for (final pin in dataPins) _val(pin, states)];

    if ([enable, a, b, ...data].any((s) => s == SignalState.highZ)) {
      return {yPin: SignalState.unknown};
    }
    if (enable == SignalState.unknown) return {yPin: SignalState.unknown};
    if (enable == SignalState.high) return {yPin: SignalState.low};
    if (a == SignalState.unknown || b == SignalState.unknown) {
      return {yPin: SignalState.unknown};
    }

    final sel =
        (b == SignalState.high ? 2 : 0) | (a == SignalState.high ? 1 : 0);
    return {yPin: data[sel]};
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
