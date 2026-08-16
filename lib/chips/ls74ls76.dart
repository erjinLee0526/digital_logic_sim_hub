import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS76 — Dual JK Flip-Flop with Set and Clear (DIP-16).
///
/// Physical pin layout (top view, notch up):
/// ```
///         +---\/---+
///  1CLK 1 |        | 16 1K
/// ~1PRE 2 |        | 15 1Q
/// ~1CLR 3 |        | 14 ~1Q
///   1J  4 | 74LS76 | 13 GND
///   VCC 5 |        | 12 2K
///  2CLK 6 |        | 11 2Q
/// ~2PRE 7 |        | 10 ~2Q
/// ~2CLR 8 |________| 9  2J
/// ```
///
/// Each flip-flop transfers J and K on the HIGH-to-LOW (falling) clock
/// transition. ~PRE and ~CLR are asynchronous, active-low inputs with
/// priority over CLK, J and K.
class Chip74LS76 extends ChipDefinition {
  @override
  String get model => '74LS76';

  @override
  String get description => '双 JK 触发器';

  @override
  String get functionSummary => '双路下降沿触发的 JK 触发器，各自带异步置位 ~PRE 与异步清零 ~CLR；'
      '当时钟从高电平跳变到低电平时按 J、K 完成置位、清零、翻转或保持。';

  @override
  List<String> get datasheetNotes => const [
        '~PRE 与 ~CLR 均为低电平有效，且优先级高于时钟；两者同时为低时 Q 与 ~Q 都输出高电平（非稳定状态）。',
        '仅当时钟从高电平跳变到低电平时采样 J、K：J=1 置位，K=1 清零，J=K=1 翻转，J=K=0 保持。',
      ];

  @override
  int get propagationDelayPs => 20000;

  @override
  double get width => 80;

  @override
  double get height => 180;

  @override
  Map<String, SignalState> get initialState => const {
        'ff1_prev_clk': SignalState.unknown,
        'ff2_prev_clk': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: '1CLK', direction: PinDirection.input),
    PinDefinition(number: 2, label: '~1PRE', direction: PinDirection.input),
    PinDefinition(number: 3, label: '~1CLR', direction: PinDirection.input),
    PinDefinition(number: 4, label: '1J', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 6, label: '2CLK', direction: PinDirection.input),
    PinDefinition(number: 7, label: '~2PRE', direction: PinDirection.input),
    PinDefinition(number: 8, label: '~2CLR', direction: PinDirection.input),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: '1K', direction: PinDirection.input),
    PinDefinition(number: 15, label: '1Q', direction: PinDirection.output),
    PinDefinition(number: 14, label: '~1Q', direction: PinDirection.output),
    PinDefinition(number: 13, label: 'GND', direction: PinDirection.ground),
    PinDefinition(number: 12, label: '2K', direction: PinDirection.input),
    PinDefinition(number: 11, label: '2Q', direction: PinDirection.output),
    PinDefinition(number: 10, label: '~2Q', direction: PinDirection.output),
    PinDefinition(number: 9, label: '2J', direction: PinDirection.input),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};

    final ff1 = _evaluateFlipFlop(
      prevClockKey: 'ff1_prev_clk',
      pre: _val(2, inputStates),
      clear: _val(3, inputStates),
      clock: _val(1, inputStates),
      j: _val(4, inputStates),
      k: _val(16, inputStates),
      currentQ: _val(15, inputStates),
      currentQBar: _val(14, inputStates),
      state: state,
    );

    final ff2 = _evaluateFlipFlop(
      prevClockKey: 'ff2_prev_clk',
      pre: _val(7, inputStates),
      clear: _val(8, inputStates),
      clock: _val(6, inputStates),
      j: _val(9, inputStates),
      k: _val(12, inputStates),
      currentQ: _val(11, inputStates),
      currentQBar: _val(10, inputStates),
      state: state,
    );

    return {
      15: ff1.$1,
      14: ff1.$2,
      11: ff2.$1,
      10: ff2.$2,
    };
  }

  static (SignalState, SignalState) _evaluateFlipFlop({
    required String prevClockKey,
    required SignalState pre,
    required SignalState clear,
    required SignalState clock,
    required SignalState j,
    required SignalState k,
    required SignalState currentQ,
    required SignalState currentQBar,
    required Map<String, SignalState> state,
  }) {
    final previousClock = state[prevClockKey] ?? SignalState.unknown;
    state[prevClockKey] = clock;

    // Both asynchronous controls active is the non-stable configuration:
    // the real device drives both Q and ~Q high.
    if (pre == SignalState.low && clear == SignalState.low) {
      return (SignalState.high, SignalState.high);
    }

    // Asynchronous preset.
    if (pre == SignalState.low) {
      return (SignalState.high, SignalState.low);
    }

    // Asynchronous clear.
    if (clear == SignalState.low) {
      return (SignalState.low, SignalState.high);
    }

    // Falling edge: sample J and K. Treat unknown -> low as an edge so a
    // manually toggled switch works from the initial unknown state.
    if (clock == SignalState.low && previousClock != SignalState.low) {
      if (!j.isDriven || !k.isDriven) {
        return (SignalState.unknown, SignalState.unknown);
      }

      if (j == SignalState.high && k == SignalState.high) {
        // Toggle: the complementary outputs exchange values.
        return (currentQBar, currentQ);
      }
      if (j == SignalState.high) {
        return (SignalState.high, SignalState.low);
      }
      if (k == SignalState.high) {
        return (SignalState.low, SignalState.high);
      }
      // J = K = 0: hold the current value.
      return (currentQ, currentQBar);
    }

    // No active edge: hold the current value.
    return (currentQ, currentQBar);
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
