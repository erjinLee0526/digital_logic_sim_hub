import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS42 - BCD-to-Decimal (1-of-10) Decoder, Active-Low Outputs (DIP-16).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   Y0  1 |        | 16  VCC
///   Y1  2 |        | 15  A0
///   Y2  3 | 74LS42 | 14  A1
///   Y3  4 |        | 13  A2
///   Y4  5 |        | 12  A3
///   Y5  6 |        | 11  Y9
///   Y6  7 |        | 10  Y8
///  GND  8 |________| 9   Y7
/// ```
///
/// Inputs A0(15, LSB)..A3(12, MSB) select exactly one active-low output.
/// BCD codes 0-9 assert the matching Yn low; invalid codes 10-15 leave all
/// outputs high. Any floating/unknown input makes every output unknown.
class Chip74LS42 extends ChipDefinition {
  @override
  String get model => '74LS42';

  @override
  String get description => 'BCD → 十进制译码器';

  @override
  String get functionSummary =>
      '把 4 位 BCD 码（0–9）译成 10 路低有效输出：只有与输入码对应的一路'
      '输出为低电平，其余全部为高电平；输入 10–15 非法码时，10 路输出'
      '全部为高电平。';

  @override
  int get propagationDelayPs => 18000; // ~18ns typical

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: 'Y0', direction: PinDirection.output),
    PinDefinition(number: 2, label: 'Y1', direction: PinDirection.output),
    PinDefinition(number: 3, label: 'Y2', direction: PinDirection.output),
    PinDefinition(number: 4, label: 'Y3', direction: PinDirection.output),
    PinDefinition(number: 5, label: 'Y4', direction: PinDirection.output),
    PinDefinition(number: 6, label: 'Y5', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'Y6', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'A0', direction: PinDirection.input),
    PinDefinition(number: 14, label: 'A1', direction: PinDirection.input),
    PinDefinition(number: 13, label: 'A2', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'A3', direction: PinDirection.input),
    PinDefinition(number: 11, label: 'Y9', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'Y8', direction: PinDirection.output),
    PinDefinition(number: 9, label: 'Y7', direction: PinDirection.output),
  ];

  static const _outputPins = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(
          name: '译码器',
          inputPins: [12, 13, 14, 15],
          outputPins: _outputPins,
        ),
      ];

  @override
  List<String> get datasheetNotes => const [
        '输入码 10–15（1010–1111）为非法 BCD 码，10 路输出全部为高电平。',
        '任一输入为悬空（Z）或未知（X）时，所有输出为未知。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final a3 = _val(12, inputStates);
    final a2 = _val(13, inputStates);
    final a1 = _val(14, inputStates);
    final a0 = _val(15, inputStates);

    final allUnknown = {
      for (final pin in _outputPins) pin: SignalState.unknown,
    };
    if (!a3.isDriven || !a2.isDriven || !a1.isDriven || !a0.isDriven) {
      return allUnknown;
    }

    final code = (a3 == SignalState.high ? 8 : 0) |
        (a2 == SignalState.high ? 4 : 0) |
        (a1 == SignalState.high ? 2 : 0) |
        (a0 == SignalState.high ? 1 : 0);

    return {
      for (var i = 0; i < _outputPins.length; i++)
        _outputPins[i]:
            i == code ? SignalState.low : SignalState.high,
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
