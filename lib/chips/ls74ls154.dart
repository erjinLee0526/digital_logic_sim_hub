import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS154 - 4-to-16 Line Decoder/Demultiplexer, Active-Low Outputs (DIP-24).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   Y0  1 |        | 24  VCC
///   Y1  2 |        | 23  A
///   Y2  3 |        | 22  B
///   Y3  4 |        | 21  C
///   Y4  5 |        | 20  D
///   Y5  6 | 74LS154 | 19  ~G2
///   Y6  7 |        | 18  ~G1
///   Y7  8 |        | 17  Y15
///   Y8  9 |        | 16  Y14
///   Y9 10 |        | 15  Y13
///  Y10 11 |        | 14  Y12
///  GND 12 |________| 13  Y11
/// ```
///
/// Decodes the 4-bit address D C B A (D = MSB) into one of sixteen
/// active-low outputs while both strobes ~G1 and ~G2 are low. Either
/// strobe high disables the chip and drives all outputs high.
class Chip74LS154 extends ChipDefinition {
  @override
  String get model => '74LS154';

  @override
  String get description => '4-16 线\n译码器\n双低有效使能';

  @override
  String get functionSummary =>
      '4-16 线译码器/多路分配器：两个使能 ~G1、~G2 都为低时，按 4 位'
      '地址 D C B A（D 为高位）把一路输出置为低电平、其余 15 路为高；'
      '任一使能为高时 16 路输出全部为高电平。';

  @override
  int get propagationDelayPs => 23000; // ~23ns typical (data to output)

  @override
  double get width => 100;

  @override
  double get height => 240;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-12)
    PinDefinition(number: 1, label: 'Y0', direction: PinDirection.output),
    PinDefinition(number: 2, label: 'Y1', direction: PinDirection.output),
    PinDefinition(number: 3, label: 'Y2', direction: PinDirection.output),
    PinDefinition(number: 4, label: 'Y3', direction: PinDirection.output),
    PinDefinition(number: 5, label: 'Y4', direction: PinDirection.output),
    PinDefinition(number: 6, label: 'Y5', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'Y6', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'Y7', direction: PinDirection.output),
    PinDefinition(number: 9, label: 'Y8', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'Y9', direction: PinDirection.output),
    PinDefinition(number: 11, label: 'Y10', direction: PinDirection.output),
    PinDefinition(number: 12, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 24-13)
    PinDefinition(number: 24, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 23, label: 'A', direction: PinDirection.input),
    PinDefinition(number: 22, label: 'B', direction: PinDirection.input),
    PinDefinition(number: 21, label: 'C', direction: PinDirection.input),
    PinDefinition(number: 20, label: 'D', direction: PinDirection.input),
    PinDefinition(number: 19, label: '~G2', direction: PinDirection.input),
    PinDefinition(number: 18, label: '~G1', direction: PinDirection.input),
    PinDefinition(number: 17, label: 'Y15', direction: PinDirection.output),
    PinDefinition(number: 16, label: 'Y14', direction: PinDirection.output),
    PinDefinition(number: 15, label: 'Y13', direction: PinDirection.output),
    PinDefinition(number: 14, label: 'Y12', direction: PinDirection.output),
    PinDefinition(number: 13, label: 'Y11', direction: PinDirection.output),
  ];

  static const _outputPins = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17,
  ];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(
          name: '译码器',
          inputPins: [18, 19, 20, 21, 22, 23],
          outputPins: _outputPins,
        ),
      ];

  @override
  List<String> get datasheetNotes => const [
        '任一使能为高（~G1 或 ~G2 高）时，16 路输出全部为高电平，与地址无关。',
        '两个使能都为低但地址未知（X）时，所有输出为未知；任一输入悬空（Z）时，所有输出为未知。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final a = _val(23, inputStates);
    final b = _val(22, inputStates);
    final c = _val(21, inputStates);
    final d = _val(20, inputStates);
    final g1 = _val(18, inputStates);
    final g2 = _val(19, inputStates);

    final allUnknown = {
      for (final pin in _outputPins) pin: SignalState.unknown,
    };
    if ([a, b, c, d, g1, g2].any((s) => s == SignalState.highZ)) {
      return allUnknown;
    }
    if (g1 == SignalState.unknown || g2 == SignalState.unknown) {
      return allUnknown;
    }
    if (g1 == SignalState.high || g2 == SignalState.high) {
      return {for (final pin in _outputPins) pin: SignalState.high};
    }
    if ([a, b, c, d].any((s) => s == SignalState.unknown)) {
      return allUnknown;
    }

    final code = (d == SignalState.high ? 8 : 0) |
        (c == SignalState.high ? 4 : 0) |
        (b == SignalState.high ? 2 : 0) |
        (a == SignalState.high ? 1 : 0);
    return {
      for (var i = 0; i < _outputPins.length; i++)
        _outputPins[i]: i == code ? SignalState.low : SignalState.high,
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
