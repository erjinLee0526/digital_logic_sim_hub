import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS148 - 8-to-3 Octal Priority Encoder, Active-Low I/O (DIP-16).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   I4  1 |        | 16  VCC
///   I5  2 |        | 15  EO
///   I6  3 |        | 14  GS
///   I7  4 | 74LS148 | 13  I3
///   EI  5 |        | 12  I2
///   A2  6 |        | 11  I1
///   A1  7 |        | 10  I0
///  GND  8 |________| 9   A0
/// ```
///
/// All inputs and outputs are active-low. With EI low the highest-numbered
/// active (low) input wins and its number is encoded inverted on A2A1A0;
/// GS goes low to flag a valid code. EI high disables the chip (A=111,
/// GS=1, EO=1); with EI low and no active input, EO goes low to enable a
/// cascaded lower-priority chip.
class Chip74LS148 extends ChipDefinition {
  @override
  String get model => '74LS148';

  @override
  String get description => '8-3 线\n优先编码器\n低有效 I/O';

  @override
  String get functionSummary =>
      '8-3 线优先编码器（输入输出均低有效）：使能 EI 为低时，编号最大的'
      '低电平输入 I7–I0 胜出，其编号以反码输出到 A2A1A0，GS 输出低表示'
      '编码有效。EI 为高时芯片禁用；EI 为低且无输入有效时 EO 输出低，'
      '用于级联下一片低优先级编码器。';

  @override
  int get propagationDelayPs => 14000; // ~14ns typical

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
    PinDefinition(number: 5, label: 'EI', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'A2', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'A1', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'EO', direction: PinDirection.output),
    PinDefinition(number: 14, label: 'GS', direction: PinDirection.output),
    PinDefinition(number: 13, label: 'I3', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'I2', direction: PinDirection.input),
    PinDefinition(number: 11, label: 'I1', direction: PinDirection.input),
    PinDefinition(number: 10, label: 'I0', direction: PinDirection.input),
    PinDefinition(number: 9, label: 'A0', direction: PinDirection.output),
  ];

  static const _inputPins = [4, 3, 2, 1, 13, 12, 11, 10]; // I7..I0

  @override
  List<String> get datasheetNotes => const [
        '优先级 I7 > I6 > … > I0：编号最大的低电平输入胜出。',
        'EI 为高时芯片禁用：A2A1A0=111、GS=1、EO=1。',
        'EI 为低且所有输入都为高（无有效输入）时：A2A1A0=111、GS=1、EO=0。',
        'A2A1A0 是胜出输入编号的二进制反码（如 I7 有效 → 000，I0 有效 → 111）。',
        '任一输入悬空（Z）或未知（X）时，输出为未知。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    const unknownResult = {
      6: SignalState.unknown,
      7: SignalState.unknown,
      9: SignalState.unknown,
      14: SignalState.unknown,
      15: SignalState.unknown,
    };
    final ei = _val(5, inputStates);
    if (ei == SignalState.highZ || ei == SignalState.unknown) {
      return unknownResult;
    }
    if (ei == SignalState.high) {
      return const {
        6: SignalState.high,
        7: SignalState.high,
        9: SignalState.high,
        14: SignalState.high,
        15: SignalState.high,
      };
    }

    for (var i = 0; i < _inputPins.length; i++) {
      final s = _val(_inputPins[i], inputStates);
      if (s == SignalState.highZ || s == SignalState.unknown) {
        return unknownResult;
      }
      if (s == SignalState.low) {
        final encoded = i; // Inverted number of I7..I0 (I7 -> 0 -> 000)
        return {
          6: SignalState.fromBool((encoded & 4) != 0),
          7: SignalState.fromBool((encoded & 2) != 0),
          9: SignalState.fromBool((encoded & 1) != 0),
          14: SignalState.low, // GS active
          15: SignalState.high, // EO inactive
        };
      }
    }

    // EI low, no active input.
    return const {
      6: SignalState.high,
      7: SignalState.high,
      9: SignalState.high,
      14: SignalState.high, // GS inactive
      15: SignalState.low, // EO enables the next stage
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
