import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS95 — 4-Bit Parallel-Access Shift Register (DIP-14).
///
/// Physical pin layout (top view, notch up):
/// ```text
///          +---\/---+
///    DS   1 |        | 14 VCC
///    P0   2 |        | 13 Q0
///    P1   3 |        | 12 Q1
///    P2   4 | 74LS95 | 11 Q2
///    P3   5 |        | 10 Q3
///     S   6 |        | 9  CP1
///    GND  7 |________| 8  CP2
/// ```
///
/// With mode control S low, a high-to-low transition of CP1 shifts right:
/// DS enters Q0 and Q0~Q2 move to Q1~Q3. With S high, a high-to-low
/// transition of CP2 loads P0~P3 in parallel into Q0~Q3. There is no
/// clear input, so the register powers up unknown.
class Chip74LS95 extends ChipDefinition {
  @override
  String get model => '74LS95';

  @override
  String get description => '4 位移位寄存器';

  @override
  String get functionSummary => '4 位并行存取移位寄存器；S 为低时 CP1 下降沿右移'
      '（DS 进入 Q0），S 为高时 CP2 下降沿并行置入 P0~P3，无清零输入。';

  @override
  List<String> get datasheetNotes => const [
        'S 为低电平时选中串行时钟 CP1，高电平时选中并行时钟 CP2，转移都发生在高到低跳变。',
        '右移时 DS 进入 Q0，Q0→Q1、Q1→Q2、Q2→Q3。',
        '无清零输入，上电后寄存器内容为未知（unknown），直到并行置入或移位产生有效值。',
      ];

  @override
  int get propagationDelayPs => 20000;

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  Map<String, SignalState> get initialState => {
        'prev_cp1': SignalState.unknown,
        'prev_cp2': SignalState.unknown,
        for (var i = 0; i < 4; i++) 'q$i': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-7)
    PinDefinition(number: 1, label: 'DS', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'P0', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'P1', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'P2', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'P3', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'S', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 14-8)
    PinDefinition(number: 14, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 13, label: 'Q0', direction: PinDirection.output),
    PinDefinition(number: 12, label: 'Q1', direction: PinDirection.output),
    PinDefinition(number: 11, label: 'Q2', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'Q3', direction: PinDirection.output),
    PinDefinition(number: 9, label: 'CP1', direction: PinDirection.input),
    PinDefinition(number: 8, label: 'CP2', direction: PinDirection.input),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final s = _val(6, inputStates);
    final cp1 = _val(9, inputStates);
    final cp2 = _val(8, inputStates);
    final previousCp1 = state['prev_cp1'] ?? SignalState.unknown;
    final previousCp2 = state['prev_cp2'] ?? SignalState.unknown;
    state['prev_cp1'] = cp1;
    state['prev_cp2'] = cp2;

    if (s == SignalState.low &&
        cp1 == SignalState.low &&
        previousCp1 == SignalState.high) {
      _shift(state, inputStates);
    } else if (s == SignalState.high &&
        cp2 == SignalState.low &&
        previousCp2 == SignalState.high) {
      _load(state, inputStates);
    }
    // Unknown S or no selected falling edge: hold the current value.

    return {
      13: state['q0'] ?? SignalState.unknown,
      12: state['q1'] ?? SignalState.unknown,
      11: state['q2'] ?? SignalState.unknown,
      10: state['q3'] ?? SignalState.unknown,
    };
  }

  static void _shift(
    Map<String, SignalState> state,
    Map<int, SignalState> inputStates,
  ) {
    final ds = inputStates[1] ?? SignalState.unknown;
    final q0 = state['q0'] ?? SignalState.unknown;
    final q1 = state['q1'] ?? SignalState.unknown;
    final q2 = state['q2'] ?? SignalState.unknown;

    state['q0'] = ds.isDriven ? ds : SignalState.unknown;
    state['q1'] = q0;
    state['q2'] = q1;
    state['q3'] = q2;
  }

  static void _load(
    Map<String, SignalState> state,
    Map<int, SignalState> inputStates,
  ) {
    // P0=2, P1=3, P2=4, P3=5.
    const dataPins = [2, 3, 4, 5];
    for (var i = 0; i < 4; i++) {
      final data = inputStates[dataPins[i]] ?? SignalState.unknown;
      state['q$i'] = data.isDriven ? data : SignalState.unknown;
    }
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
