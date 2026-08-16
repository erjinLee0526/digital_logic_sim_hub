import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS175 — Quad D-Type Positive-Edge-Triggered Flip-Flop with Clear.
///
/// DIP-16 pin layout (top view, notch up):
/// ```
///          +---\/---+
///   ~MR  1 |        | 16 VCC
///   1Q   2 |        | 15 4Q
///  ~1Q   3 |        | 14 ~4Q
///   1D   4 |        | 13 4D
///   2D   5 | 74LS175| 12 3D
///  ~2Q   6 |        | 11 3Q
///   2Q   7 |        | 10 ~3Q
///   GND  8 |________| 9  CP
/// ```
///
/// The common CP input loads all four D inputs on its rising edge. A low
/// level on ~MR asynchronously clears every flip-flop, overriding CP.
class Chip74LS175 extends ChipDefinition {
  @override
  String get model => '74LS175';

  @override
  String get description => '4 路\nD 触发器';

  @override
  String get functionSummary => '四路上升沿触发的 D 触发器，共用时钟 CP 和异步清零输入 '
      '~MR；每个触发器提供互补输出 Q 与 /Q。';

  @override
  List<String> get datasheetNotes => const [
        '~MR 为低电平有效，优先级高于时钟，会把全部 Q 清为低电平。',
        '仅当 CP 从非高电平变为高电平时才采样 D，其余时间输出保持。',
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
    PinDefinition(number: 2, label: '1Q', direction: PinDirection.output),
    PinDefinition(number: 3, label: '~1Q', direction: PinDirection.output),
    PinDefinition(number: 4, label: '1D', direction: PinDirection.input),
    PinDefinition(number: 5, label: '2D', direction: PinDirection.input),
    PinDefinition(number: 6, label: '~2Q', direction: PinDirection.output),
    PinDefinition(number: 7, label: '2Q', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: '4Q', direction: PinDirection.output),
    PinDefinition(number: 14, label: '~4Q', direction: PinDirection.output),
    PinDefinition(number: 13, label: '4D', direction: PinDirection.input),
    PinDefinition(number: 12, label: '3D', direction: PinDirection.input),
    PinDefinition(number: 11, label: '3Q', direction: PinDirection.output),
    PinDefinition(number: 10, label: '~3Q', direction: PinDirection.output),
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

    // FF index, D pin, Q pin, /Q pin.
    const flipFlops = [
      (4, 2, 3),
      (5, 7, 6),
      (12, 11, 10),
      (13, 15, 14),
    ];

    for (final ff in flipFlops) {
      final (dPin, qPin, qBarPin) = ff;
      if (clear == SignalState.low) {
        result[qPin] = SignalState.low;
        result[qBarPin] = SignalState.high;
        continue;
      }

      if (isEdge) {
        final data = _val(dPin, inputStates);
        final q = data.isDriven ? data : SignalState.unknown;
        result[qPin] = q;
        result[qBarPin] = q.not();
        continue;
      }

      // No active edge: hold the current output values.
      result[qPin] = _val(qPin, inputStates);
      result[qBarPin] = _val(qBarPin, inputStates);
    }

    return result;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
