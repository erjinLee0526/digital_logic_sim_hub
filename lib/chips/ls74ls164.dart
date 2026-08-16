import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS164 — 8-Bit Serial-In / Parallel-Out Shift Register.
///
/// DIP-14 pin layout (top view, notch up):
/// ```
///          +---\/---+
///     A  1 |        | 14 VCC
///     B  2 |        | 13 Q7
///    Q0  3 |        | 12 Q6
///    Q1  4 | 74LS164| 11 Q5
///    Q2  5 |        | 10 Q4
///    Q3  6 |        | 9  ~MR
///   GND  7 |________| 8  CP
/// ```
///
/// On every rising edge of CP the register shifts toward Q7: Q0 receives
/// (A AND B), and the old Qn value moves to Q(n+1). A low level on ~MR
/// asynchronously clears all eight outputs.
class Chip74LS164 extends ChipDefinition {
  @override
  String get model => '74LS164';

  @override
  String get description => '8 位\n移位寄存器';

  @override
  String get functionSummary => '八位串行输入、并行输出的移位寄存器；A 与 B 相与后作为串行'
      '数据，CP 每个上升沿由 Q0 向 Q7 移一位，~MR 低电平异步清零。';

  @override
  List<String> get datasheetNotes => const [
        '串行数据等于 A 与 B 的逻辑与；只使用一个输入时可将另一个固定为高电平。',
        '~MR 为低电平有效，优先级高于 CP，会把 Q0~Q7 全部清为低电平。',
      ];

  @override
  int get propagationDelayPs => 20000;

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  Map<String, SignalState> get initialState => {
        'prev_clk': SignalState.unknown,
        for (var i = 0; i < 8; i++) 'q$i': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-7)
    PinDefinition(number: 1, label: 'A', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'B', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'Q0', direction: PinDirection.output),
    PinDefinition(number: 4, label: 'Q1', direction: PinDirection.output),
    PinDefinition(number: 5, label: 'Q2', direction: PinDirection.output),
    PinDefinition(number: 6, label: 'Q3', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 14-8)
    PinDefinition(number: 14, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 13, label: 'Q7', direction: PinDirection.output),
    PinDefinition(number: 12, label: 'Q6', direction: PinDirection.output),
    PinDefinition(number: 11, label: 'Q5', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'Q4', direction: PinDirection.output),
    PinDefinition(number: 9, label: '~MR', direction: PinDirection.input),
    PinDefinition(number: 8, label: 'CP', direction: PinDirection.input),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final clear = _val(9, inputStates);
    final clock = _val(8, inputStates);
    final previousClock = state['prev_clk'] ?? SignalState.unknown;
    state['prev_clk'] = clock;

    const qPins = [3, 4, 5, 6, 10, 11, 12, 13];
    final result = <int, SignalState>{};

    if (clear == SignalState.low) {
      for (var i = 0; i < qPins.length; i++) {
        state['q$i'] = SignalState.low;
        result[qPins[i]] = SignalState.low;
      }
      return result;
    }

    final isEdge =
        clock == SignalState.high && previousClock != SignalState.high;
    if (isEdge) {
      // Shift toward Q7: Q0 = A AND B, Q(n) = old Q(n-1).
      final serial =
          SignalState.and(_val(1, inputStates), _val(2, inputStates));
      final next = <int, SignalState>{
        for (var i = 0; i < qPins.length; i++)
          i: state['q${i - 1}'] ?? SignalState.unknown,
      };
      next[0] = serial.isDriven ? serial : SignalState.unknown;
      for (var i = 0; i < qPins.length; i++) {
        state['q$i'] = next[i]!;
      }
    }

    for (var i = 0; i < qPins.length; i++) {
      result[qPins[i]] = state['q$i'] ?? SignalState.unknown;
    }
    return result;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
