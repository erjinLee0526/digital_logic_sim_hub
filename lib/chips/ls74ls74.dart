import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS74 — Dual D-Type Positive-Edge-Triggered Flip-Flop (DIP-14).
///
/// Physical pin layout (top view, notch up):
/// ```
///         +---\/---+
/// ~1CLR 1 |        | 14 VCC
///   1D  2 |        | 13 ~2CLR
///  1CLK 3 |        | 12 2D
/// ~1PRE 4 | 74LS74 | 11 2CLK
///   1Q  5 |        | 10 ~2PRE
///  ~1Q  6 |        | 9  2Q
///  GND  7 |________| 8  ~2Q
/// ```
///
/// Each flip-flop samples D on the rising edge of CLK. /PRE and /CLR are
/// asynchronous, active-low inputs with priority over CLK and D.
class Chip74LS74 extends ChipDefinition {
  @override
  String get model => '74LS74';

  @override
  String get description => '双 D 触发器';

  @override
  int get propagationDelayPs => 20000; // ~20ns typical for 74LS74

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  Map<String, SignalState> get initialState => const {
        'ff1_prev_clk': SignalState.unknown,
        'ff2_prev_clk': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1–7)
    PinDefinition(number: 1, label: '~1CLR', direction: PinDirection.input),
    PinDefinition(number: 2, label: '1D', direction: PinDirection.input),
    PinDefinition(number: 3, label: '1CLK', direction: PinDirection.input),
    PinDefinition(number: 4, label: '~1PRE', direction: PinDirection.input),
    PinDefinition(number: 5, label: '1Q', direction: PinDirection.output),
    PinDefinition(number: 6, label: '~1Q', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 14–8)
    PinDefinition(number: 14, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 13, label: '~2CLR', direction: PinDirection.input),
    PinDefinition(number: 12, label: '2D', direction: PinDirection.input),
    PinDefinition(number: 11, label: '2CLK', direction: PinDirection.input),
    PinDefinition(number: 10, label: '~2PRE', direction: PinDirection.input),
    PinDefinition(number: 9, label: '2Q', direction: PinDirection.output),
    PinDefinition(number: 8, label: '~2Q', direction: PinDirection.output),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};

    final ff1 = _evaluateFlipFlop(
      prevClockKey: 'ff1_prev_clk',
      pre: _val(4, inputStates),
      clear: _val(1, inputStates),
      clock: _val(3, inputStates),
      data: _val(2, inputStates),
      currentQ: _val(5, inputStates),
      currentQBar: _val(6, inputStates),
      state: state,
    );

    final ff2 = _evaluateFlipFlop(
      prevClockKey: 'ff2_prev_clk',
      pre: _val(10, inputStates),
      clear: _val(13, inputStates),
      clock: _val(11, inputStates),
      data: _val(12, inputStates),
      currentQ: _val(9, inputStates),
      currentQBar: _val(8, inputStates),
      state: state,
    );

    return {
      5: ff1.$1,
      6: ff1.$2,
      9: ff2.$1,
      8: ff2.$2,
    };
  }

  static (SignalState, SignalState) _evaluateFlipFlop({
    required String prevClockKey,
    required SignalState pre,
    required SignalState clear,
    required SignalState clock,
    required SignalState data,
    required SignalState currentQ,
    required SignalState currentQBar,
    required Map<String, SignalState> state,
  }) {
    final previousClock = state[prevClockKey] ?? SignalState.unknown;
    state[prevClockKey] = clock;

    // Both asynchronous controls active is the non-stable configuration:
    // the real device drives both Q and /Q high.
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

    // Rising edge: sample D. Treat unknown → high as an edge so a manually
    // toggled switch works from the initial unknown state.
    if (clock == SignalState.high && previousClock != SignalState.high) {
      if (data.isDriven) {
        return (data, data.not());
      }
      return (SignalState.unknown, SignalState.unknown);
    }

    // No active edge: hold the current value.
    return (currentQ, currentQBar);
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
