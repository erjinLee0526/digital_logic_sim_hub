import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS195 — Universal 4-Bit Parallel-Access Shift Register (DIP-16).
///
/// Physical pin layout (top view, notch up):
/// ```
///          +---\/---+
///   ~MR  1 |        | 16 VCC
///    J   2 |        | 15 Q0
///   ~K   3 |        | 14 Q1
///    P0  4 | 74LS195| 13 Q2
///    P1  5 |        | 12 Q3
///    P2  6 |        | 11 ~Q3
///    P3  7 |        | 10 CP
///   GND  8 |________| 9  ~PE
/// ```
///
/// A low level on ~MR asynchronously clears the register. On each rising
/// edge of CP the register either loads P0~P3 in parallel (~PE low) or
/// shifts right one bit (~PE high), with the first stage driven by J and
/// the active-low ~K serial input.
class Chip74LS195 extends ChipDefinition {
  @override
  String get model => '74LS195';

  @override
  String get description => '4 位移位寄存器';

  @override
  String get functionSummary => '4 位并行存取移位寄存器，~MR 低电平异步清零；'
      'CP 上升沿时按 ~PE 选择并行置数或右移，右移时首级由 J 与低有效的 ~K 串行输入决定。';

  @override
  List<String> get datasheetNotes => const [
        '~MR 为低电平有效且优先级最高，异步清零全部 Q0~Q3。',
        '~PE 低电平时在 CP 上升沿并行置数 P0~P3；高电平时右移一位。',
        '~K 为低有效（反相 K）输入：J=1、~K=1 置首级为 1，J=0、~K=0 清为 0，'
            'J=1、~K=0 翻转，J=0、~K=1 保持；J 与 ~K 并接可当 D 型串行输入。',
      ];

  @override
  int get propagationDelayPs => 20000;

  @override
  double get width => 80;

  @override
  double get height => 180;

  @override
  Map<String, SignalState> get initialState => {
        'prev_clk': SignalState.unknown,
        for (var i = 0; i < 4; i++) 'q$i': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: '~MR', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'J', direction: PinDirection.input),
    PinDefinition(number: 3, label: '~K', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'P0', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'P1', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'P2', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'P3', direction: PinDirection.input),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'Q0', direction: PinDirection.output),
    PinDefinition(number: 14, label: 'Q1', direction: PinDirection.output),
    PinDefinition(number: 13, label: 'Q2', direction: PinDirection.output),
    PinDefinition(number: 12, label: 'Q3', direction: PinDirection.output),
    PinDefinition(number: 11, label: '~Q3', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'CP', direction: PinDirection.input),
    PinDefinition(number: 9, label: '~PE', direction: PinDirection.input),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final mr = _val(1, inputStates);
    final pe = _val(9, inputStates);
    final cp = _val(10, inputStates);
    final j = _val(2, inputStates);
    final k = _val(3, inputStates);
    final previousClock = state['prev_clk'] ?? SignalState.unknown;
    state['prev_clk'] = cp;

    if (mr == SignalState.low) {
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.low;
      }
    } else if (cp == SignalState.high && previousClock != SignalState.high) {
      if (pe == SignalState.low) {
        _load(state, inputStates);
      } else if (pe == SignalState.high) {
        _shift(state, j: j, k: k);
      }
      // Unknown or highZ ~PE: hold the current value.
    }

    final q0 = state['q0'] ?? SignalState.unknown;
    final q1 = state['q1'] ?? SignalState.unknown;
    final q2 = state['q2'] ?? SignalState.unknown;
    final q3 = state['q3'] ?? SignalState.unknown;

    return {
      15: q0,
      14: q1,
      13: q2,
      12: q3,
      11: q3.not(),
    };
  }

  static void _load(
    Map<String, SignalState> state,
    Map<int, SignalState> inputStates,
  ) {
    // P0=4, P1=5, P2=6, P3=7.
    const dataPins = [4, 5, 6, 7];
    for (var i = 0; i < 4; i++) {
      final data = inputStates[dataPins[i]] ?? SignalState.unknown;
      state['q$i'] = data.isDriven ? data : SignalState.unknown;
    }
  }

  static void _shift(
    Map<String, SignalState> state, {
    required SignalState j,
    required SignalState k,
  }) {
    final q0 = state['q0'] ?? SignalState.unknown;
    final q1 = state['q1'] ?? SignalState.unknown;
    final q2 = state['q2'] ?? SignalState.unknown;

    state['q0'] = _firstStageNext(j, k, q0);
    state['q1'] = q0;
    state['q2'] = q1;
    state['q3'] = q2;
  }

  /// Next state of the first stage from J and the active-low ~K input.
  static SignalState _firstStageNext(
    SignalState j,
    SignalState k,
    SignalState q0,
  ) {
    if (!j.isDriven || !k.isDriven) return SignalState.unknown;
    if (j == SignalState.high && k == SignalState.high) {
      return SignalState.high; // Set.
    }
    if (j == SignalState.low && k == SignalState.low) {
      return SignalState.low; // Reset.
    }
    if (j == SignalState.high && k == SignalState.low) {
      return q0.not(); // Toggle.
    }
    return q0; // Hold (J low, ~K high).
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
