import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS30 - 8-Input Positive NAND Gate (DIP-14).
///
/// Pins 9, 10 and 13 are NC (no connection) on the real package; they are
/// not modeled as pins.
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///    A  1 |        | 14  VCC
///    B  2 |        | 13  NC
///    C  3 |        | 12  H
///    D  4 | 74LS30 | 11  G
///    E  5 |        | 10  NC
///    F  6 |        | 9   NC
///  GND  7 |________| 8   Y
/// ```
///
/// Single 8-input NAND gate: Y is low only when all eight inputs A-H are
/// high; any low input forces Y high.
class Chip74LS30 extends ChipDefinition {
  @override
  String get model => '74LS30';

  @override
  String get description => '8 输入\n与非门';

  @override
  String get functionSummary =>
      '单个 8 输入与非门：只有当 A–H 八个输入都为高电平时输出才为低'
      '电平，任意输入为低电平输出即为高电平。';

  @override
  int get propagationDelayPs => 10000; // ~10ns typical

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-7)
    PinDefinition(number: 1, label: 'A', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'B', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'C', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'D', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'E', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'F', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 14-8; pins 13, 10, 9 are NC and omitted)
    PinDefinition(number: 14, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 12, label: 'H', direction: PinDirection.input),
    PinDefinition(number: 11, label: 'G', direction: PinDirection.input),
    PinDefinition(number: 8, label: 'Y', direction: PinDirection.output),
  ];

  static const _inputPins = [1, 2, 3, 4, 5, 6, 11, 12];

  @override
  List<String> get datasheetNotes => const [
        '9、10、13 脚为 NC（空脚），无内部连接，仿真中未建模。',
        '无逐行真值表：8 个输入共 256 种组合，手册不逐行列出。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final inputs = [for (final pin in _inputPins) _val(pin, inputStates)];
    if (inputs.any((s) => s == SignalState.highZ)) {
      return const {8: SignalState.unknown};
    }
    if (inputs.any((s) => s == SignalState.low)) {
      return const {8: SignalState.high};
    }
    if (inputs.every((s) => s == SignalState.high)) {
      return const {8: SignalState.low};
    }
    return const {8: SignalState.unknown};
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
