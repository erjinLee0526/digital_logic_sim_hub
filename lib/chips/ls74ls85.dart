import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS85 - 4-Bit Magnitude Comparator with Cascading Inputs (DIP-16).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   B3  1 |        | 16  VCC
///  IA<B 2 |        | 15  A3
///  IA=B 3 |        | 14  B2
///  IA>B 4 | 74LS85 | 13  A2
///  OA>B 5 |        | 12  A1
///  OA=B 6 |        | 11  B1
///  OA<B 7 |        | 10  A0
///  GND  8 |________| 9   B0
/// ```
///
/// Compares A3A2A1A0 with B3B2B1B0 starting at the most significant bit.
/// The first bit that differs decides the result. When all four bits are
/// equal the three cascade inputs (IA>B / IA=B / IA<B) pass straight
/// through to the outputs, which lets several chips be cascaded for wider
/// words.
class Chip74LS85 extends ChipDefinition {
  @override
  String get model => '74LS85';

  @override
  String get description => '4 位数值\n比较器\n级联输入';

  @override
  String get functionSummary =>
      '4 位数值比较器：把 A3–A0 与 B3–B0 从最高位开始逐位比较，首个不同'
      '的位即决定输出（OA>B / OA=B / OA<B）。四位全部相等时，输出直接'
      '跟随三个级联输入，可多片串联扩展比较位宽。';

  @override
  int get propagationDelayPs => 23000; // ~23ns typical

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: 'B3', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'IA<B', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'IA=B', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'IA>B', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'OA>B', direction: PinDirection.output),
    PinDefinition(number: 6, label: 'OA=B', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'OA<B', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'A3', direction: PinDirection.input),
    PinDefinition(number: 14, label: 'B2', direction: PinDirection.input),
    PinDefinition(number: 13, label: 'A2', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'A1', direction: PinDirection.input),
    PinDefinition(number: 11, label: 'B1', direction: PinDirection.input),
    PinDefinition(number: 10, label: 'A0', direction: PinDirection.input),
    PinDefinition(number: 9, label: 'B0', direction: PinDirection.input),
  ];

  static const _aPins = [10, 12, 13, 15]; // A0..A3
  static const _bPins = [9, 11, 14, 1]; // B0..B3

  @override
  List<String> get datasheetNotes => const [
        '从最高位 A3/B3 开始比较，首个不同的位即决定结果，低位不再影响。',
        '四位全部相等时，三个输出直接跟随级联输入 IA>B / IA=B / IA<B。',
        '无逐行真值表：8 个数据输入共 256 种组合，手册不逐行列出。',
        '任一数据位悬空（Z）或未知（X）时，三个输出全部为未知。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    for (var i = 3; i >= 0; i--) {
      final a = _val(_aPins[i], inputStates);
      final b = _val(_bPins[i], inputStates);
      if (!a.isDriven || !b.isDriven) {
        return const {
          5: SignalState.unknown,
          6: SignalState.unknown,
          7: SignalState.unknown,
        };
      }
      if (a == SignalState.high && b == SignalState.low) {
        return const {
          5: SignalState.high,
          6: SignalState.low,
          7: SignalState.low,
        };
      }
      if (a == SignalState.low && b == SignalState.high) {
        return const {
          5: SignalState.low,
          6: SignalState.low,
          7: SignalState.high,
        };
      }
    }

    // All four bits equal: cascade inputs pass through.
    SignalState cascade(int pin) {
      final s = _val(pin, inputStates);
      return s == SignalState.highZ ? SignalState.unknown : s;
    }

    return {
      5: cascade(4), // IA>B -> OA>B
      6: cascade(3), // IA=B -> OA=B
      7: cascade(2), // IA<B -> OA<B
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
