import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS283 - 4-Bit Binary Full Adder with Fast Carry (DIP-16).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   S1  1 |        | 16  VCC
///   B1  2 |        | 15  B3
///   A1  3 |        | 14  A3
///   S0  4 | 74LS283 | 13  S3
///   A0  5 |        | 12  A2
///   B0  6 |        | 11  B2
///   C0  7 |        | 10  S2
///  GND  8 |________| 9   C4
/// ```
///
/// Computes A3A2A1A0 + B3B2B1B0 + C0 as a 5-bit sum: S3..S0 carry the low
/// four bits and C4 is the outgoing carry. Any non-driven input (highZ or
/// unknown) makes all five outputs unknown.
class Chip74LS283 extends ChipDefinition {
  @override
  String get model => '74LS283';

  @override
  String get description => '4 位二进制\n全加器\nC0/C4 进位';

  @override
  String get functionSummary =>
      '4 位二进制全加器（内部超前进位）：把两个 4 位二进制数 A3–A0、B3–B0 '
      '与进位输入 C0 相加，低 4 位和由 S3–S0 输出，最高位进位由 C4 输出。'
      '任一输入未知或悬空时，所有输出均为未知。';

  @override
  int get propagationDelayPs => 16000; // ~16ns typical (sum), ~10ns carry

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: 'S1', direction: PinDirection.output),
    PinDefinition(number: 2, label: 'B1', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'A1', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'S0', direction: PinDirection.output),
    PinDefinition(number: 5, label: 'A0', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'B0', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'C0', direction: PinDirection.input),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'B3', direction: PinDirection.input),
    PinDefinition(number: 14, label: 'A3', direction: PinDirection.input),
    PinDefinition(number: 13, label: 'S3', direction: PinDirection.output),
    PinDefinition(number: 12, label: 'A2', direction: PinDirection.input),
    PinDefinition(number: 11, label: 'B2', direction: PinDirection.input),
    PinDefinition(number: 10, label: 'S2', direction: PinDirection.output),
    PinDefinition(number: 9, label: 'C4', direction: PinDirection.output),
  ];

  static const _aPins = [5, 3, 12, 14]; // A0..A3
  static const _bPins = [6, 2, 11, 15]; // B0..B3
  static const _sumPins = [4, 1, 10, 13]; // S0..S3

  @override
  List<String> get datasheetNotes => const [
        'Σ = A3A2A1A0 + B3B2B1B0 + C0，共 5 位结果：S3–S0 输出低 4 位和，C4 输出进位。',
        '任一输入悬空（Z）或未知（X）时，S3–S0 与 C4 共 5 个输出全部为未知。',
        '无逐行真值表：9 个输入共 512 种组合，手册不逐行列出。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final inputs = [
      for (final pin in [..._aPins, ..._bPins, 7]) _val(pin, inputStates),
    ];
    const allUnknown = {
      4: SignalState.unknown,
      1: SignalState.unknown,
      10: SignalState.unknown,
      13: SignalState.unknown,
      9: SignalState.unknown,
    };
    if (inputs.any((s) => !s.isDriven)) {
      return allUnknown;
    }

    int bit(SignalState s) => s == SignalState.high ? 1 : 0;
    var a = 0;
    var b = 0;
    for (var i = 0; i < 4; i++) {
      a |= bit(inputs[i]) << i;
      b |= bit(inputs[i + 4]) << i;
    }
    final total = a + b + bit(inputs[8]);

    return {
      for (var i = 0; i < _sumPins.length; i++)
        _sumPins[i]: SignalState.fromBool((total & (1 << i)) != 0),
      9: SignalState.fromBool((total & 16) != 0),
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
