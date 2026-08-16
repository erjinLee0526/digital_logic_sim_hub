import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS139 - Dual 2-to-4 Line Decoder, Active-Low Enable and Outputs (DIP-16).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///  ~1G  1 |        | 16  VCC
///   1A  2 |        | 15  ~2G
///   1B  3 | 74LS139 | 14  2A
/// ~1Y0  4 |        | 13  2B
/// ~1Y1  5 |        | 12  ~2Y0
/// ~1Y2  6 |        | 11  ~2Y1
/// ~1Y3  7 |        | 10  ~2Y2
///  GND  8 |________| 9   ~2Y3
/// ```
///
/// Each half is enabled while its ~G is low; the select code (B A) asserts
/// exactly one active-low output. Disabled -> all four outputs high.
class Chip74LS139 extends ChipDefinition {
  @override
  String get model => '74LS139';

  @override
  String get description => '双 2-4 线\n译码器\n低有效输出';

  @override
  String get functionSummary =>
      '内含两个独立的 2-4 线译码器。每个译码器在其使能 ~G 为低时工作：'
      '按两位地址（A/B）把一路输出置为低电平，其余为高；~G 为高时该组 '
      '4 路输出全部为高电平。';

  @override
  int get propagationDelayPs => 21000; // ~21ns typical

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: '~1G', direction: PinDirection.input),
    PinDefinition(number: 2, label: '1A', direction: PinDirection.input),
    PinDefinition(number: 3, label: '1B', direction: PinDirection.input),
    PinDefinition(number: 4, label: '~1Y0', direction: PinDirection.output),
    PinDefinition(number: 5, label: '~1Y1', direction: PinDirection.output),
    PinDefinition(number: 6, label: '~1Y2', direction: PinDirection.output),
    PinDefinition(number: 7, label: '~1Y3', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: '~2G', direction: PinDirection.input),
    PinDefinition(number: 14, label: '2A', direction: PinDirection.input),
    PinDefinition(number: 13, label: '2B', direction: PinDirection.input),
    PinDefinition(number: 12, label: '~2Y0', direction: PinDirection.output),
    PinDefinition(number: 11, label: '~2Y1', direction: PinDirection.output),
    PinDefinition(number: 10, label: '~2Y2', direction: PinDirection.output),
    PinDefinition(number: 9, label: '~2Y3', direction: PinDirection.output),
  ];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(
            name: '译码器 1', inputPins: [1, 2, 3], outputPins: [4, 5, 6, 7]),
        TruthTableGroup(
            name: '译码器 2', inputPins: [15, 14, 13], outputPins: [12, 11, 10, 9]),
      ];

  @override
  List<String> get datasheetNotes => const [
        '使能 ~G 为高时，该组 4 路输出全部为高电平，与地址无关。',
        '使能 ~G 为低但地址未知（X）时，该组输出为未知；任一输入悬空（Z）时，该组输出为未知。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    return {
      ..._evaluateHalf(
        enable: _val(1, inputStates),
        a: _val(2, inputStates),
        b: _val(3, inputStates),
        outputPins: const [4, 5, 6, 7],
      ),
      ..._evaluateHalf(
        enable: _val(15, inputStates),
        a: _val(14, inputStates),
        b: _val(13, inputStates),
        outputPins: const [12, 11, 10, 9],
      ),
    };
  }

  static Map<int, SignalState> _evaluateHalf({
    required SignalState enable,
    required SignalState a,
    required SignalState b,
    required List<int> outputPins,
  }) {
    final allUnknown = {
      for (final pin in outputPins) pin: SignalState.unknown,
    };
    if ([enable, a, b].any((s) => s == SignalState.highZ)) {
      return allUnknown;
    }
    if (enable == SignalState.unknown) return allUnknown;
    if (enable == SignalState.high) {
      return {for (final pin in outputPins) pin: SignalState.high};
    }
    if ([a, b].any((s) => s == SignalState.unknown)) return allUnknown;

    final code =
        (b == SignalState.high ? 2 : 0) | (a == SignalState.high ? 1 : 0);
    return {
      for (var i = 0; i < outputPins.length; i++)
        outputPins[i]: i == code ? SignalState.low : SignalState.high,
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
