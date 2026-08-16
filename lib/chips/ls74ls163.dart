import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS163 — Synchronous 4-Bit Binary Counter with Synchronous Clear.
///
/// DIP-16 pin layout (top view, notch up):
/// ```
///          +---\/---+
///   ~CLR 1 |        | 16 VCC
///    CLK 2 |        | 15 RCO
///     P0 3 |        | 14 Q3
///     P1 4 | 74LS163| 13 Q2
///     P2 5 |        | 12 Q1
///     P3 6 |        | 11 Q0
///    ENP 7 |        | 10 ENT
///    GND 8 |________| 9  ~LOAD
/// ```
///
/// Unlike the 74LS161, the ~CLR input of this part is synchronous: it only
/// clears the counter on a rising edge of CLK. On that edge the priority is
/// clear, then parallel load (~LOAD low), then count (ENP and ENT high), and
/// finally hold. RCO is high when ENT and all four Q outputs are high.
class Chip74LS163 extends ChipDefinition {
  @override
  String get model => '74LS163';

  @override
  String get description => '4 位\n同步计数器';

  @override
  String get functionSummary => '四位同步二进制计数器（0~15 循环）；~CLR 与 ~LOAD 都是'
      '同步控制，仅在 CLK 上升沿生效，优先级依次为清零、置数、计数（ENP/ENT 同为高）、'
      '保持；计数到 15 时 RCO 输出高电平。';

  @override
  List<String> get datasheetNotes => const [
        '~CLR 为低电平有效，但只在 CLK 上升沿清零，与 74LS161 的异步清零不同。',
        '~LOAD 为低电平有效的同步置数；仅当 ENP 与 ENT 同时为高电平时计数。',
        'RCO = ENT 与 Q0、Q1、Q2、Q3 的逻辑与，计数到 15 且 ENT 为高时'
            '为高电平。',
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
    PinDefinition(number: 1, label: '~CLR', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'CLK', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'P0', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'P1', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'P2', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'P3', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'ENP', direction: PinDirection.input),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'RCO', direction: PinDirection.output),
    PinDefinition(number: 14, label: 'Q3', direction: PinDirection.output),
    PinDefinition(number: 13, label: 'Q2', direction: PinDirection.output),
    PinDefinition(number: 12, label: 'Q1', direction: PinDirection.output),
    PinDefinition(number: 11, label: 'Q0', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'ENT', direction: PinDirection.input),
    PinDefinition(number: 9, label: '~LOAD', direction: PinDirection.input),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final clear = _val(1, inputStates);
    final clock = _val(2, inputStates);
    final previousClock = state['prev_clk'] ?? SignalState.unknown;
    state['prev_clk'] = clock;

    final isEdge =
        clock == SignalState.high && previousClock != SignalState.high;
    if (isEdge) {
      final load = _val(9, inputStates);
      if (clear == SignalState.low) {
        for (var i = 0; i < 4; i++) {
          state['q$i'] = SignalState.low;
        }
      } else if (load == SignalState.low) {
        for (var i = 0; i < 4; i++) {
          final data = _val(3 + i, inputStates);
          state['q$i'] = data.isDriven ? data : SignalState.unknown;
        }
      } else if (_val(7, inputStates) == SignalState.high &&
          _val(10, inputStates) == SignalState.high) {
        final q0 = state['q0'];
        final q1 = state['q1'];
        final q2 = state['q2'];
        final q3 = state['q3'];
        if (q0 != null &&
            q1 != null &&
            q2 != null &&
            q3 != null &&
            q0.isDriven &&
            q1.isDriven &&
            q2.isDriven &&
            q3.isDriven) {
          final value = (q3 == SignalState.high ? 8 : 0) +
              (q2 == SignalState.high ? 4 : 0) +
              (q1 == SignalState.high ? 2 : 0) +
              (q0 == SignalState.high ? 1 : 0);
          final next = (value + 1) & 0xf;
          state['q0'] = SignalState.fromBool((next & 1) != 0);
          state['q1'] = SignalState.fromBool((next & 2) != 0);
          state['q2'] = SignalState.fromBool((next & 4) != 0);
          state['q3'] = SignalState.fromBool((next & 8) != 0);
        } else {
          for (var i = 0; i < 4; i++) {
            state['q$i'] = SignalState.unknown;
          }
        }
      }
    }

    final q0 = state['q0'] ?? SignalState.unknown;
    final q1 = state['q1'] ?? SignalState.unknown;
    final q2 = state['q2'] ?? SignalState.unknown;
    final q3 = state['q3'] ?? SignalState.unknown;
    final ent = _val(10, inputStates);

    SignalState rco;
    if (ent == SignalState.low) {
      rco = SignalState.low;
    } else if (ent == SignalState.high &&
        q0.isDriven &&
        q1.isDriven &&
        q2.isDriven &&
        q3.isDriven) {
      rco = q0 == SignalState.high &&
              q1 == SignalState.high &&
              q2 == SignalState.high &&
              q3 == SignalState.high
          ? SignalState.high
          : SignalState.low;
    } else {
      rco = SignalState.unknown;
    }

    return {
      11: q0,
      12: q1,
      13: q2,
      14: q3,
      15: rco,
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
