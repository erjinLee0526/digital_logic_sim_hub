import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS75 — 4-Bit Bistable Latch with Complementary Outputs (DIP-16).
///
/// Physical pin layout (top view, notch up):
/// ```text
///          +---\/---+
///   ~Q0  1 |        | 16 Q0
///    D0  2 |        | 15 Q1
///    D1  3 |        | 14 ~Q1
///  E2-3  4 | 74LS75 | 13 E0-1
///    VCC 5 |        | 12 GND
///    D2  6 |        | 11 Q2
///    D3  7 |        | 10 ~Q2
///   ~Q3  8 |________| 9  Q3
/// ```
///
/// While an enable input is high the corresponding latches are transparent
/// (Q follows D). When the enable falls, each latch retains the last data
/// value. E0-1 controls latches 0 and 1; E2-3 controls latches 2 and 3.
class Chip74LS75 extends ChipDefinition {
  @override
  String get model => '74LS75';

  @override
  String get description => '4 位\n双稳态锁存器';

  @override
  String get functionSummary => '四位电平敏感 D 锁存器，每路输出互补的 Q 与 ~Q；'
      'E0-1 使能第 0/1 路、E2-3 使能第 2/3 路，使能为高时 Q 跟随 D，'
      '使能下降沿锁存当前数据。';

  @override
  List<String> get datasheetNotes => const [
        '使能为高电平有效：为高时对应锁存器透明（Q=D），降为低时锁存下降沿前的数据。',
        'E0-1 控制 D0/D1 两路，E2-3 控制 D2/D3 两路；无清零输入。',
      ];

  @override
  int get propagationDelayPs => 15000;

  @override
  double get width => 80;

  @override
  double get height => 180;

  @override
  Map<String, SignalState> get initialState => {
        for (var i = 0; i < 4; i++) 'q$i': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: '~Q0', direction: PinDirection.output),
    PinDefinition(number: 2, label: 'D0', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'D1', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'E2-3', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 6, label: 'D2', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'D3', direction: PinDirection.input),
    PinDefinition(number: 8, label: '~Q3', direction: PinDirection.output),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'Q0', direction: PinDirection.output),
    PinDefinition(number: 15, label: 'Q1', direction: PinDirection.output),
    PinDefinition(number: 14, label: '~Q1', direction: PinDirection.output),
    PinDefinition(number: 13, label: 'E0-1', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'GND', direction: PinDirection.ground),
    PinDefinition(number: 11, label: 'Q2', direction: PinDirection.output),
    PinDefinition(number: 10, label: '~Q2', direction: PinDirection.output),
    PinDefinition(number: 9, label: 'Q3', direction: PinDirection.output),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final enable01 = _val(13, inputStates);
    final enable23 = _val(4, inputStates);
    final result = <int, SignalState>{};

    // Bit index, D pin, Q pin, ~Q pin.
    const bits = [
      (2, 16, 1),
      (3, 15, 14),
      (6, 11, 10),
      (7, 9, 8),
    ];

    for (var i = 0; i < bits.length; i++) {
      final (dPin, qPin, qnPin) = bits[i];
      final enable = i < 2 ? enable01 : enable23;
      final data = _val(dPin, inputStates);
      final key = 'q$i';

      if (enable == SignalState.high) {
        state[key] = data.isDriven ? data : SignalState.unknown;
        result[qPin] = data.isDriven ? data : SignalState.unknown;
      } else if (enable == SignalState.low) {
        final stored = state[key] ?? SignalState.unknown;
        result[qPin] = stored;
      } else {
        result[qPin] = SignalState.unknown;
      }
      result[qnPin] = result[qPin]!.not();
    }

    return result;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
