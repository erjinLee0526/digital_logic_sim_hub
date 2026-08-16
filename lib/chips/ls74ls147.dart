import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS147 - 10-to-4 Line Priority Encoder, Active-Low I/O (DIP-16).
///
/// Pin layout (top view, notch up; pin 15 is NC and not modeled):
/// ```
///         +---\/---+
///   I4  1 |        | 16  VCC
///   I5  2 |        | 15  NC
///   I6  3 |        | 14  D
///   I7  4 | 74LS147 | 13  I3
///   I8  5 |        | 12  I2
///    C  6 |        | 11  I1
///    B  7 |        | 10  I9
///  GND  8 |________| 9   A
/// ```
///
/// Inputs 1-9 and outputs A-D are all active-low. The highest-numbered
/// active (low) input wins and its BCD value is output inverted on
/// D C B A. With no active input the outputs are 1111, the same code as
/// decimal 0 (there is no input pin for 0).
class Chip74LS147 extends ChipDefinition {
  @override
  String get model => '74LS147';

  @override
  String get description => '10-4 线\n优先编码器\nBCD 反码输出';

  @override
  String get functionSummary =>
      '10 线-4 线优先编码器（输入输出均低有效）：编号最大的有效输入 '
      '（1–9）胜出，其 BCD 码以反码输出到 D C B A；没有任何有效输入时'
      '输出 1111，与编码 0 相同。';

  @override
  int get propagationDelayPs => 10000; // ~10ns typical

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: 'I4', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'I5', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'I6', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'I7', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'I8', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'C', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'B', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9; pin 15 is NC and omitted)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 14, label: 'D', direction: PinDirection.output),
    PinDefinition(number: 13, label: 'I3', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'I2', direction: PinDirection.input),
    PinDefinition(number: 11, label: 'I1', direction: PinDirection.input),
    PinDefinition(number: 10, label: 'I9', direction: PinDirection.input),
    PinDefinition(number: 9, label: 'A', direction: PinDirection.output),
  ];

  /// Input pins in priority order: I9 (highest) down to I1 (lowest).
  static const _priorityPins = [10, 5, 4, 3, 2, 1, 13, 12, 11];

  @override
  List<String> get datasheetNotes => const [
        '输入 1–9 与输出 A–D 全部低有效：编号最大的有效（低）输入胜出。',
        '输出是胜出编号的 BCD 反码：9 → 0110、1 → 1110；无有效输入时输出 1111（等价于编码 0）。',
        '15 脚为 NC（空脚），无内部连接，仿真中未建模。',
        '任一输入悬空（Z）或未知（X）时输出为未知；优先级低于已确定有效输入的悬空/未知输入不影响结果。',
        '无逐行真值表：9 个输入共 512 种组合，手册不逐行列出。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    const allUnknown = {
      9: SignalState.unknown,
      7: SignalState.unknown,
      6: SignalState.unknown,
      14: SignalState.unknown,
    };

    for (var i = 0; i < _priorityPins.length; i++) {
      final s = _val(_priorityPins[i], inputStates);
      if (s == SignalState.highZ || s == SignalState.unknown) {
        return allUnknown;
      }
      if (s == SignalState.low) {
        final selected = 9 - i; // Input number that won
        final code = 15 - selected; // Inverted BCD of that number
        return {
          9: SignalState.fromBool((code & 1) != 0),
          7: SignalState.fromBool((code & 2) != 0),
          6: SignalState.fromBool((code & 4) != 0),
          14: SignalState.fromBool((code & 8) != 0),
        };
      }
    }

    // No active input: same code as decimal 0.
    return const {
      9: SignalState.high,
      7: SignalState.high,
      6: SignalState.high,
      14: SignalState.high,
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
