import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS174 — Hex D-Type Positive-Edge-Triggered Flip-Flop with Clear
/// (DIP-16).
///
/// Physical pin layout (top view, notch up):
/// ```
///          +---\/---+
///   ~MR  1 |        | 16 VCC
///   Q0   2 |        | 15 Q5
///   D0   3 |        | 14 D5
///   D1   4 | 74LS174| 13 D4
///   Q1   5 |        | 12 Q4
///   D2   6 |        | 11 D3
///   Q2   7 |        | 10 Q3
///   GND  8 |________| 9  CP
/// ```
///
/// The common CP input loads all six D inputs on its rising edge. A low
/// level on ~MR asynchronously clears every flip-flop, overriding CP.
class Chip74LS174 extends ChipDefinition {
  @override
  String get model => '74LS174';

  @override
  String get description => '六 D 触发器';

  @override
  String get functionSummary => '六路上升沿触发的 D 触发器，共用时钟 CP 与异步清零 ~MR；'
      'CP 上升沿时把 D0~D5 锁存到 Q0~Q5。';

  @override
  List<String> get datasheetNotes => const [
        '~MR 为低电平有效，优先级高于时钟，会把全部 Q0~Q5 异步清为低电平。',
        '仅当 CP 从非高电平变为高电平时才采样 D0~D5，其余时间输出保持。',
      ];

  @override
  int get propagationDelayPs => 20000;

  @override
  double get width => 80;

  @override
  double get height => 180;

  @override
  Map<String, SignalState> get initialState => const {
        'prev_clk': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: '~MR', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'Q0', direction: PinDirection.output),
    PinDefinition(number: 3, label: 'D0', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'D1', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'Q1', direction: PinDirection.output),
    PinDefinition(number: 6, label: 'D2', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'Q2', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'Q5', direction: PinDirection.output),
    PinDefinition(number: 14, label: 'D5', direction: PinDirection.input),
    PinDefinition(number: 13, label: 'D4', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'Q4', direction: PinDirection.output),
    PinDefinition(number: 11, label: 'D3', direction: PinDirection.input),
    PinDefinition(number: 10, label: 'Q3', direction: PinDirection.output),
    PinDefinition(number: 9, label: 'CP', direction: PinDirection.input),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final clear = _val(1, inputStates);
    final clock = _val(9, inputStates);
    final previousClock = state['prev_clk'] ?? SignalState.unknown;
    state['prev_clk'] = clock;

    final isEdge =
        clock == SignalState.high && previousClock != SignalState.high;
    final result = <int, SignalState>{};

    // D pin, Q pin.
    const flipFlops = [
      (3, 2),
      (4, 5),
      (6, 7),
      (11, 10),
      (13, 12),
      (14, 15),
    ];

    for (final ff in flipFlops) {
      final (dPin, qPin) = ff;
      if (clear == SignalState.low) {
        result[qPin] = SignalState.low;
        continue;
      }

      if (isEdge) {
        final data = _val(dPin, inputStates);
        result[qPin] = data.isDriven ? data : SignalState.unknown;
        continue;
      }

      // No active edge: hold the current output value.
      result[qPin] = _val(qPin, inputStates);
    }

    return result;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
