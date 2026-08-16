import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS151 - 8-to-1 Data Selector/Multiplexer with Strobe (DIP-16).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   D3  1 |        | 16  VCC
///   D2  2 |        | 15  D4
///   D1  3 | 74LS151 | 14  D5
///   D0  4 |        | 13  D6
///    Y  5 |        | 12  D7
///   ~W  6 |        | 11  A
///   ~S  7 |        | 10  B
///  GND  8 |________| 9   C
/// ```
///
/// ~S low enables the selector: Y = D selected by CBA, ~W = complement.
/// ~S high disables it: Y = 0, ~W = 1.
class Chip74LS151 extends ChipDefinition {
  @override
  String get model => '74LS151';

  @override
  String get description => '8 选 1\n数据选择器\nY/~W 输出';

  @override
  String get functionSummary =>
      '8 选 1 数据选择器。选通 ~S 为低时工作：按三位地址（CBA）从 D0–D7 中'
      '选出一路送到输出 Y，~W 输出其反相；~S 为高时输出固定为 Y=0、~W=1。';

  @override
  int get propagationDelayPs => 12500; // ~12.5ns typical

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: 'D3', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'D2', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'D1', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'D0', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'Y', direction: PinDirection.output),
    PinDefinition(number: 6, label: '~W', direction: PinDirection.output),
    PinDefinition(number: 7, label: '~S', direction: PinDirection.input),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'D4', direction: PinDirection.input),
    PinDefinition(number: 14, label: 'D5', direction: PinDirection.input),
    PinDefinition(number: 13, label: 'D6', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'D7', direction: PinDirection.input),
    PinDefinition(number: 11, label: 'A', direction: PinDirection.input),
    PinDefinition(number: 10, label: 'B', direction: PinDirection.input),
    PinDefinition(number: 9, label: 'C', direction: PinDirection.input),
  ];

  static const _dataPins = [4, 3, 2, 1, 15, 14, 13, 12];

  @override
  List<String> get datasheetNotes => const [
        '选通 ~S 为高时输出固定为 Y=0、~W=1，与地址和数据无关。',
        '选通 ~S 为低时：地址未知（X）或所选数据未知（X）→ 输出未知；任一输入悬空（Z）→ 输出未知。',
        '完整真值表含 12 个输入（4096 行），手册不逐行列出。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final strobe = _val(7, inputStates);
    final a = _val(11, inputStates);
    final b = _val(10, inputStates);
    final c = _val(9, inputStates);
    final data = [
      for (final pin in _dataPins) _val(pin, inputStates),
    ];

    const unknownResult = {5: SignalState.unknown, 6: SignalState.unknown};
    if ([strobe, a, b, c, ...data]
        .any((s) => s == SignalState.highZ)) {
      return unknownResult;
    }
    if (strobe == SignalState.unknown) return unknownResult;
    if (strobe == SignalState.high) {
      return const {5: SignalState.low, 6: SignalState.high};
    }
    if ([a, b, c].any((s) => s == SignalState.unknown)) {
      return unknownResult;
    }

    final sel = (c == SignalState.high ? 4 : 0) |
        (b == SignalState.high ? 2 : 0) |
        (a == SignalState.high ? 1 : 0);
    final y = data[sel];
    return {
      5: y,
      6: y == SignalState.unknown ? SignalState.unknown : y.not(),
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
