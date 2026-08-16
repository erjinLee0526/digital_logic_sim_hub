import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS192 — Synchronous BCD Decade Up/Down Counter with Separate Up/Down
/// Clocks (DIP-16).
///
/// Physical pin layout (top view, notch up):
/// ```
///          +---\/---+
///    P1  1 |        | 16 VCC
///    Q1  2 |        | 15 P0
///    Q0  3 |        | 14 MR
///   CPD  4 | 74LS192| 13 TCD
///   CPU  5 |        | 12 TCU
///    Q2  6 |        | 11 ~PL
///    Q3  7 |        | 10 P2
///   GND  8 |________| 9  P3
/// ```
///
/// A high level on MR asynchronously clears the counter, overriding ~PL and
/// the clocks. With MR low and ~PL low, P0~P3 load asynchronously. With both
/// high, a rising edge of CPU counts up through 0-9 while CPD is high, and a
/// rising edge of CPD counts down through 9-0 while CPU is high.
class Chip74LS192 extends ChipDefinition {
  @override
  String get model => '74LS192';

  @override
  String get description => '十进制\n加/减计数器';

  @override
  String get functionSummary => '同步十进制（BCD 8421）加/减计数器，带独立的加计数时钟 CPU 与'
      '减计数时钟 CPD；MR 高电平异步清零、~PL 低电平异步置数，'
      '并输出进位 TCU 与借位 TCD 供级联。';

  @override
  List<String> get datasheetNotes => const [
        'MR 为高电平有效且优先级最高，异步清零；~PL 为低电平有效，其次异步置数。',
        'CPD 为高时 CPU 上升沿加计数（0~9 循环），CPU 为高时 CPD 上升沿减计数（0→9）。',
        '计数到 9 且 CPU 为低时 TCU 为低，计数到 0 且 CPD 为低时 TCD 为低，其余为高。',
      ];

  @override
  int get propagationDelayPs => 20000;

  @override
  double get width => 80;

  @override
  double get height => 180;

  @override
  Map<String, SignalState> get initialState => {
        'prev_cpu': SignalState.unknown,
        'prev_cpd': SignalState.unknown,
        for (var i = 0; i < 4; i++) 'q$i': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: 'P1', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'Q1', direction: PinDirection.output),
    PinDefinition(number: 3, label: 'Q0', direction: PinDirection.output),
    PinDefinition(number: 4, label: 'CPD', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'CPU', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'Q2', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'Q3', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'P0', direction: PinDirection.input),
    PinDefinition(number: 14, label: 'MR', direction: PinDirection.input),
    PinDefinition(number: 13, label: 'TCD', direction: PinDirection.output),
    PinDefinition(number: 12, label: 'TCU', direction: PinDirection.output),
    PinDefinition(number: 11, label: '~PL', direction: PinDirection.input),
    PinDefinition(number: 10, label: 'P2', direction: PinDirection.input),
    PinDefinition(number: 9, label: 'P3', direction: PinDirection.input),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final mr = _val(14, inputStates);
    final pl = _val(11, inputStates);
    final cpu = _val(5, inputStates);
    final cpd = _val(4, inputStates);
    final previousCpu = state['prev_cpu'] ?? SignalState.unknown;
    final previousCpd = state['prev_cpd'] ?? SignalState.unknown;
    state['prev_cpu'] = cpu;
    state['prev_cpd'] = cpd;

    if (mr == SignalState.high) {
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.low;
      }
    } else if (pl == SignalState.low) {
      _load(state, inputStates);
    } else {
      final upEdge = cpu == SignalState.high && previousCpu != SignalState.high;
      final downEdge =
          cpd == SignalState.high && previousCpd != SignalState.high;

      // The inactive clock must be high for the active edge to count.
      if (upEdge && !downEdge && cpd == SignalState.high) {
        _count(state, up: true);
      } else if (downEdge && !upEdge && cpu == SignalState.high) {
        _count(state, up: false);
      }
      // Otherwise hold: no edge, both edges, or an inactive clock that is
      // low/unknown.
    }

    final q0 = state['q0'] ?? SignalState.unknown;
    final q1 = state['q1'] ?? SignalState.unknown;
    final q2 = state['q2'] ?? SignalState.unknown;
    final q3 = state['q3'] ?? SignalState.unknown;
    final value = _decode(state);

    return {
      3: q0,
      2: q1,
      6: q2,
      7: q3,
      12: _carry(cpu: cpu, value: value),
      13: _borrow(cpd: cpd, value: value),
    };
  }

  static void _load(
    Map<String, SignalState> state,
    Map<int, SignalState> inputStates,
  ) {
    // P0=15, P1=1, P2=10, P3=9.
    const dataPins = [15, 1, 10, 9];
    for (var i = 0; i < 4; i++) {
      final data = inputStates[dataPins[i]] ?? SignalState.unknown;
      state['q$i'] = data.isDriven ? data : SignalState.unknown;
    }
  }

  static void _count(Map<String, SignalState> state, {required bool up}) {
    final value = _decode(state);
    if (value == null) {
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.unknown;
      }
      return;
    }

    final next = up ? (value + 1) % 10 : (value == 0 ? 9 : value - 1);
    _encode(next, state);
  }

  static int? _decode(Map<String, SignalState> state) {
    final q0 = state['q0'];
    final q1 = state['q1'];
    final q2 = state['q2'];
    final q3 = state['q3'];
    if (q0 == null ||
        q1 == null ||
        q2 == null ||
        q3 == null ||
        !q0.isDriven ||
        !q1.isDriven ||
        !q2.isDriven ||
        !q3.isDriven) {
      return null;
    }
    return (q3 == SignalState.high ? 8 : 0) +
        (q2 == SignalState.high ? 4 : 0) +
        (q1 == SignalState.high ? 2 : 0) +
        (q0 == SignalState.high ? 1 : 0);
  }

  static void _encode(int value, Map<String, SignalState> state) {
    state['q0'] = SignalState.fromBool((value & 1) != 0);
    state['q1'] = SignalState.fromBool((value & 2) != 0);
    state['q2'] = SignalState.fromBool((value & 4) != 0);
    state['q3'] = SignalState.fromBool((value & 8) != 0);
  }

  /// TCU = ~(/CPU * Q0 * Q3): low at count 9 while CPU is low.
  static SignalState _carry({
    required SignalState cpu,
    required int? value,
  }) {
    if (cpu == SignalState.low) {
      if (value == null) return SignalState.unknown;
      return value == 9 ? SignalState.low : SignalState.high;
    }
    if (cpu != SignalState.high) return SignalState.unknown;
    // With CPU high the carry window has closed.
    return SignalState.high;
  }

  /// TCD = ~(/CPD * /Q0 * /Q1 * /Q2 * /Q3): low at count 0 while CPD is low.
  static SignalState _borrow({
    required SignalState cpd,
    required int? value,
  }) {
    if (cpd == SignalState.low) {
      if (value == null) return SignalState.unknown;
      return value == 0 ? SignalState.low : SignalState.high;
    }
    if (cpd != SignalState.high) return SignalState.unknown;
    // With CPD high the borrow window has closed.
    return SignalState.high;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
