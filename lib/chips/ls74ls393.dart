import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS393 — Dual 4-Bit Binary Ripple Counter.
///
/// DIP-14 pin layout (top view, notch up):
/// ```
///          +---\/---+
///   1CP  1 |        | 14 VCC
///   1MR  2 |        | 13 2CP
///   1Q0  3 |        | 12 2MR
///   1Q1  4 | 74LS393| 11 2Q0
///   1Q2  5 |        | 10 2Q1
///   1Q3  6 |        | 9  2Q2
///   GND  7 |________| 8  2Q3
/// ```
///
/// The two independent counters count the high-to-low transitions of their
/// own clock input through the 0-15 binary sequence. A high level on the
/// section's MR input asynchronously clears that section, overriding CP.
class Chip74LS393 extends ChipDefinition {
  @override
  String get model => '74LS393';

  @override
  String get description => '双 4 位\n二进制计数器';

  @override
  String get functionSummary => '两个独立的异步 4 位二进制计数器（各按 0~15 循环）；'
      '每个计数器在自身 CP 的高到低跳变计数，并有独立的 MR 高电平异步清零输入。';

  @override
  List<String> get datasheetNotes => const [
        '1MR / 2MR 为高电平有效，优先级高于对应时钟，会把该组 Q0~Q3 清为低电平。',
        '计数发生在 CP 从高到低的跳变，两组计数器完全独立。',
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
        for (var i = 0; i < 4; i++) 'q1$i': SignalState.unknown,
        for (var i = 0; i < 4; i++) 'q2$i': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-7)
    PinDefinition(number: 1, label: '1CP', direction: PinDirection.input),
    PinDefinition(number: 2, label: '1MR', direction: PinDirection.input),
    PinDefinition(number: 3, label: '1Q0', direction: PinDirection.output),
    PinDefinition(number: 4, label: '1Q1', direction: PinDirection.output),
    PinDefinition(number: 5, label: '1Q2', direction: PinDirection.output),
    PinDefinition(number: 6, label: '1Q3', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 14-8)
    PinDefinition(number: 14, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 13, label: '2CP', direction: PinDirection.input),
    PinDefinition(number: 12, label: '2MR', direction: PinDirection.input),
    PinDefinition(number: 11, label: '2Q0', direction: PinDirection.output),
    PinDefinition(number: 10, label: '2Q1', direction: PinDirection.output),
    PinDefinition(number: 9, label: '2Q2', direction: PinDirection.output),
    PinDefinition(number: 8, label: '2Q3', direction: PinDirection.output),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final result = <int, SignalState>{};

    result.addAll(_evaluateSection(
      state: state,
      prefix: 'q1',
      clock: _val(1, inputStates),
      previousClockKey: 'prev_cp1',
      reset: _val(2, inputStates),
      outputPins: const {0: 3, 1: 4, 2: 5, 3: 6},
    ));

    result.addAll(_evaluateSection(
      state: state,
      prefix: 'q2',
      clock: _val(13, inputStates),
      previousClockKey: 'prev_cp2',
      reset: _val(12, inputStates),
      outputPins: const {0: 11, 1: 10, 2: 9, 3: 8},
    ));

    return result;
  }

  static Map<int, SignalState> _evaluateSection({
    required Map<String, SignalState> state,
    required String prefix,
    required SignalState clock,
    required String previousClockKey,
    required SignalState reset,
    required Map<int, int> outputPins,
  }) {
    final previousClock = state[previousClockKey] ?? SignalState.unknown;
    state[previousClockKey] = clock;

    if (reset == SignalState.high) {
      for (var i = 0; i < 4; i++) {
        state['$prefix$i'] = SignalState.low;
      }
    } else if (clock == SignalState.low && previousClock == SignalState.high) {
      final q0 = state['${prefix}0'];
      final q1 = state['${prefix}1'];
      final q2 = state['${prefix}2'];
      final q3 = state['${prefix}3'];
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
        state['${prefix}0'] = SignalState.fromBool((next & 1) != 0);
        state['${prefix}1'] = SignalState.fromBool((next & 2) != 0);
        state['${prefix}2'] = SignalState.fromBool((next & 4) != 0);
        state['${prefix}3'] = SignalState.fromBool((next & 8) != 0);
      } else {
        for (var i = 0; i < 4; i++) {
          state['$prefix$i'] = SignalState.unknown;
        }
      }
    }

    return {
      for (var i = 0; i < 4; i++)
        outputPins[i]!: state['$prefix$i'] ?? SignalState.unknown,
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
