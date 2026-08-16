import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS138 - 3-to-8 Line Decoder/Demultiplexer, Active-Low Outputs (DIP-16).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///    A  1 |        | 16  VCC
///    B  2 |        | 15  ~Y0
///    C  3 | 74LS138 | 14  ~Y1
/// ~G2A 4 |        | 13  ~Y2
/// ~G2B 5 |        | 12  ~Y3
///   G1 6 |        | 11  ~Y4
///  ~Y7 7 |        | 10  ~Y5
///  GND 8 |________| 9   ~Y6
/// ```
///
/// Enabled when G1 is high and both ~G2A/~G2B are low; then exactly one
/// output (selected by CBA) is low. Disabled -> all outputs high.
class Chip74LS138 extends ChipDefinition {
  @override
  String get model => '74LS138';

  @override
  String get description => '3-8 线译码器\n低有效输出\n三使能端';

  @override
  String get functionSummary =>
      '把 3 位地址（A/B/C）译成 8 路低有效输出：只有与地址对应的一路输出'
      '为低电平。仅当 G1 为高、~G2A 与 ~G2B 都为低时芯片才工作，使能不'
      '满足时 8 路输出全部为高电平。';

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
    PinDefinition(number: 1, label: 'A', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'B', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'C', direction: PinDirection.input),
    PinDefinition(number: 4, label: '~G2A', direction: PinDirection.input),
    PinDefinition(number: 5, label: '~G2B', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'G1', direction: PinDirection.input),
    PinDefinition(number: 7, label: '~Y7', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: '~Y0', direction: PinDirection.output),
    PinDefinition(number: 14, label: '~Y1', direction: PinDirection.output),
    PinDefinition(number: 13, label: '~Y2', direction: PinDirection.output),
    PinDefinition(number: 12, label: '~Y3', direction: PinDirection.output),
    PinDefinition(number: 11, label: '~Y4', direction: PinDirection.output),
    PinDefinition(number: 10, label: '~Y5', direction: PinDirection.output),
    PinDefinition(number: 9, label: '~Y6', direction: PinDirection.output),
  ];

  static const _outputPins = [15, 14, 13, 12, 11, 10, 9, 7];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(
          name: '译码器',
          inputPins: [1, 2, 3, 4, 5, 6],
          outputPins: _outputPins,
        ),
      ];

  @override
  List<String> get datasheetNotes => const [
        '使能不满足（G1 为低，或 ~G2A/~G2B 任意为高）时，8 路输出全部为高电平，与地址无关。',
        '使能满足但地址未知（X）时，所有输出为未知；任一输入悬空（Z）时，所有输出为未知。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final a = _val(1, inputStates);
    final b = _val(2, inputStates);
    final c = _val(3, inputStates);
    final g1 = _val(6, inputStates);
    final g2a = _val(4, inputStates);
    final g2b = _val(5, inputStates);

    final allUnknown = {
      for (final pin in _outputPins) pin: SignalState.unknown,
    };
    if ([a, b, c, g1, g2a, g2b]
        .any((s) => s == SignalState.highZ)) {
      return allUnknown;
    }
    if ([g1, g2a, g2b]
        .any((s) => s == SignalState.unknown)) {
      return allUnknown;
    }

    final enabled =
        g1 == SignalState.high && g2a == SignalState.low && g2b == SignalState.low;
    if (!enabled) {
      return {for (final pin in _outputPins) pin: SignalState.high};
    }
    if ([a, b, c].any((s) => s == SignalState.unknown)) {
      return allUnknown;
    }

    final code = (c == SignalState.high ? 4 : 0) |
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
