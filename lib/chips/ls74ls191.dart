import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS191 — Synchronous 4-Bit Binary Up/Down Counter (DIP-16).
///
/// Physical pin layout (top view, notch up):
/// ```
///          +---\/---+
///    P1  1 |        | 16 VCC
///    Q1  2 |        | 15 P0
///    Q0  3 |        | 14 CP
///   ~CE  4 | 74LS191| 13 RC
///   U/D  5 |        | 12 TC
///    Q2  6 |        | 11 ~PL
///    Q3  7 |        | 10 P2
///   GND  8 |________| 9  P3
/// ```
///
/// A low level on ~PL asynchronously loads P0~P3. With ~PL high and ~CE
/// low, each rising edge of CP counts once: U/D low counts up through
/// 0-15 and U/D high counts down through 15-0. TC goes high at the terminal
/// count; RC is normally high and pulses low while CP, ~CE and TC are all
/// active.
class Chip74LS191 extends ChipDefinition {
  @override
  String get model => '74LS191';

  @override
  String get description => '4 位二进制\n加/减计数器';

  @override
  String get functionSummary => '同步 4 位二进制加/减计数器，单一 CP 上升沿计数；'
      '~PL 低电平异步置数，~CE 低电平使能计数，U/D 低电平加、高电平减，'
      '并输出 TC 与 RC 两个级联信号。';

  @override
  List<String> get datasheetNotes => const [
        '~PL 为低电平有效且优先级最高，会把 P0~P3 异步装入计数器。',
        '仅当 ~CE 为低时在 CP 上升沿计数：U/D 为低时 0~15 循环加，为高时 0→15 减。',
        'TC 在加计数到 15 或减计数到 0 时为高；RC 平时为高，仅当 ~CE 低、TC 高且 CP 高时为低。',
      ];

  @override
  int get propagationDelayPs => 20000;

  @override
  double get width => 80;

  @override
  double get height => 180;

  @override
  Map<String, SignalState> get initialState => {
        'prev_cp': SignalState.unknown,
        for (var i = 0; i < 4; i++) 'q$i': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: 'P1', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'Q1', direction: PinDirection.output),
    PinDefinition(number: 3, label: 'Q0', direction: PinDirection.output),
    PinDefinition(number: 4, label: '~CE', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'U/D', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'Q2', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'Q3', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'P0', direction: PinDirection.input),
    PinDefinition(number: 14, label: 'CP', direction: PinDirection.input),
    PinDefinition(number: 13, label: 'RC', direction: PinDirection.output),
    PinDefinition(number: 12, label: 'TC', direction: PinDirection.output),
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
    final pl = _val(11, inputStates);
    final cp = _val(14, inputStates);
    final ce = _val(4, inputStates);
    final upDown = _val(5, inputStates);
    final previousCp = state['prev_cp'] ?? SignalState.unknown;
    state['prev_cp'] = cp;

    if (pl == SignalState.low) {
      _load(state, inputStates);
    } else if (cp == SignalState.high &&
        previousCp != SignalState.high &&
        ce == SignalState.low) {
      if (upDown == SignalState.low) {
        _count(state, up: true, modulus: 16);
      } else if (upDown == SignalState.high) {
        _count(state, up: false, modulus: 16);
      }
      // Unknown or highZ direction: hold the current value.
    }

    final value = _decode(state);
    final q0 = state['q0'] ?? SignalState.unknown;
    final q1 = state['q1'] ?? SignalState.unknown;
    final q2 = state['q2'] ?? SignalState.unknown;
    final q3 = state['q3'] ?? SignalState.unknown;

    final tc = _terminalCount(upDown: upDown, value: value, maxValue: 15);
    final rc = _rippleClock(ce: ce, tc: tc, cp: cp);

    return {
      3: q0,
      2: q1,
      6: q2,
      7: q3,
      12: tc,
      13: rc,
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

  static void _count(
    Map<String, SignalState> state, {
    required bool up,
    required int modulus,
  }) {
    final value = _decode(state);
    if (value == null) {
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.unknown;
      }
      return;
    }

    final next =
        up ? (value + 1) % modulus : (value == 0 ? modulus - 1 : value - 1);
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

  static SignalState _terminalCount({
    required SignalState upDown,
    required int? value,
    required int maxValue,
  }) {
    if (value == null) return SignalState.unknown;
    if (upDown == SignalState.low) {
      return value == maxValue ? SignalState.high : SignalState.low;
    }
    if (upDown == SignalState.high) {
      return value == 0 ? SignalState.high : SignalState.low;
    }
    return SignalState.unknown;
  }

  static SignalState _rippleClock({
    required SignalState ce,
    required SignalState tc,
    required SignalState cp,
  }) {
    if (ce == SignalState.low &&
        tc == SignalState.high &&
        cp == SignalState.high) {
      return SignalState.low;
    }
    if (ce == SignalState.high ||
        tc == SignalState.low ||
        cp == SignalState.low) {
      return SignalState.high;
    }
    return SignalState.unknown;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
