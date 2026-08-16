import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS273 — Octal D-Type Positive-Edge-Triggered Flip-Flop with Clear.
///
/// DIP-20 pin layout (top view, notch up):
/// ```
///          +---\/---+
///   ~MR  1 |        | 20 VCC
///   1Q   2 |        | 19 8Q
///   1D   3 |        | 18 8D
///   2D   4 |        | 17 7D
///   2Q   5 |        | 16 7Q
///   3Q   6 |        | 15 6Q
///   3D   7 |        | 14 6D
///   4D   8 |        | 13 5D
///   4Q   9 |        | 12 5Q
///   GND 10 |________| 11 CP
/// ```
///
/// The common CP input loads all eight D inputs on its rising edge. A low
/// level on ~MR asynchronously clears every flip-flop, overriding CP.
class Chip74LS273 extends ChipDefinition {
  @override
  String get model => '74LS273';

  @override
  String get description => '8 位\nD 触发器';

  @override
  String get functionSummary => '八路上升沿触发的 D 触发器，共用时钟 CP 和异步清零输入 '
      '~MR；数据在 CP 上升沿锁存到 Q0~Q7。';

  @override
  List<String> get datasheetNotes => const [
        '~MR 为低电平有效，优先级高于时钟，会把全部 Q 清为低电平。',
        '仅当 CP 从非高电平变为高电平时才采样 D，其余时间输出保持。',
      ];

  @override
  int get propagationDelayPs => 20000;

  @override
  double get width => 100;

  @override
  double get height => 220;

  @override
  Map<String, SignalState> get initialState => const {
        'prev_clk': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-10)
    PinDefinition(number: 1, label: '~MR', direction: PinDirection.input),
    PinDefinition(number: 2, label: '1Q', direction: PinDirection.output),
    PinDefinition(number: 3, label: '1D', direction: PinDirection.input),
    PinDefinition(number: 4, label: '2D', direction: PinDirection.input),
    PinDefinition(number: 5, label: '2Q', direction: PinDirection.output),
    PinDefinition(number: 6, label: '3Q', direction: PinDirection.output),
    PinDefinition(number: 7, label: '3D', direction: PinDirection.input),
    PinDefinition(number: 8, label: '4D', direction: PinDirection.input),
    PinDefinition(number: 9, label: '4Q', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 20-11)
    PinDefinition(number: 20, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 19, label: '8Q', direction: PinDirection.output),
    PinDefinition(number: 18, label: '8D', direction: PinDirection.input),
    PinDefinition(number: 17, label: '7D', direction: PinDirection.input),
    PinDefinition(number: 16, label: '7Q', direction: PinDirection.output),
    PinDefinition(number: 15, label: '6Q', direction: PinDirection.output),
    PinDefinition(number: 14, label: '6D', direction: PinDirection.input),
    PinDefinition(number: 13, label: '5D', direction: PinDirection.input),
    PinDefinition(number: 12, label: '5Q', direction: PinDirection.output),
    PinDefinition(number: 11, label: 'CP', direction: PinDirection.input),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final clear = _val(1, inputStates);
    final clock = _val(11, inputStates);
    final previousClock = state['prev_clk'] ?? SignalState.unknown;
    state['prev_clk'] = clock;

    final isEdge =
        clock == SignalState.high && previousClock != SignalState.high;
    final result = <int, SignalState>{};

    // Bit index, D pin, Q pin.
    const flipFlops = [
      (3, 2),
      (4, 5),
      (7, 6),
      (8, 9),
      (13, 12),
      (14, 15),
      (17, 16),
      (18, 19),
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

      result[qPin] = _val(qPin, inputStates);
    }

    return result;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
