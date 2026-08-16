import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS194 — 4-Bit Bidirectional Universal Shift Register.
///
/// DIP-16 pin layout (top view, notch up):
/// ```
///          +---\/---+
///   ~MR  1 |        | 16 VCC
///    DSR 2 |        | 15 S1
///     P0 3 |        | 14 S0
///     P1 4 | 74LS194| 13 CP
///     P2 5 |        | 12 Q3
///     P3 6 |        | 11 Q2
///    DSL 7 |        | 10 Q1
///   GND  8 |________| 9  Q0
/// ```
///
/// A low level on ~MR asynchronously clears the register. On each rising
/// edge of CP the S1/S0 mode selects hold (00), shift right (01), shift
/// left (10), or parallel load (11). DSR and DSL are the right/left serial
/// data inputs.
class Chip74LS194 extends ChipDefinition {
  @override
  String get model => '74LS194';

  @override
  String get description => '4 位\n通用移位寄存器';

  @override
  String get functionSummary => '四位双向通用移位寄存器；~MR 低电平异步清零，CP 上升沿'
      '按 S1/S0 选择 保持（00）、右移（01，DSR 进入 Q0）、左移（10，DSL 进入 Q3）'
      '或并行置数（11，P0~P3）。';

  @override
  List<String> get datasheetNotes => const [
        '~MR 为低电平有效，优先级高于 CP，会把 Q0~Q3 全部清为低电平。',
        'S1/S0 = 00 保持、01 右移、10 左移、11 并行置数；模式在 CP 上升沿生效。',
        'S1 或 S0 为 unknown/highZ 时无法确定工作模式，输出按 unknown 处理。',
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
    PinDefinition(number: 2, label: 'DSR', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'P0', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'P1', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'P2', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'P3', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'DSL', direction: PinDirection.input),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'S1', direction: PinDirection.input),
    PinDefinition(number: 14, label: 'S0', direction: PinDirection.input),
    PinDefinition(number: 13, label: 'CP', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'Q3', direction: PinDirection.output),
    PinDefinition(number: 11, label: 'Q2', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'Q1', direction: PinDirection.output),
    PinDefinition(number: 9, label: 'Q0', direction: PinDirection.output),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final clear = _val(1, inputStates);
    final clock = _val(13, inputStates);
    final previousClock = state['prev_clk'] ?? SignalState.unknown;
    state['prev_clk'] = clock;

    if (clear == SignalState.low) {
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.low;
      }
    } else if (clock == SignalState.high && previousClock != SignalState.high) {
      final s0 = _val(14, inputStates);
      final s1 = _val(15, inputStates);

      if (s1 == SignalState.high && s0 == SignalState.high) {
        for (var i = 0; i < 4; i++) {
          final data = _val(3 + i, inputStates);
          state['q$i'] = data.isDriven ? data : SignalState.unknown;
        }
      } else if (s1 == SignalState.low && s0 == SignalState.high) {
        final dsr = _val(2, inputStates);
        final old = [for (var i = 0; i < 4; i++) state['q$i']];
        state['q0'] = dsr.isDriven ? dsr : SignalState.unknown;
        for (var i = 1; i < 4; i++) {
          state['q$i'] = old[i - 1] ?? SignalState.unknown;
        }
      } else if (s1 == SignalState.high && s0 == SignalState.low) {
        final dsl = _val(7, inputStates);
        final old = [for (var i = 0; i < 4; i++) state['q$i']];
        state['q3'] = dsl.isDriven ? dsl : SignalState.unknown;
        for (var i = 0; i < 3; i++) {
          state['q$i'] = old[i + 1] ?? SignalState.unknown;
        }
      } else if (s1 == SignalState.low && s0 == SignalState.low) {
        // Hold: leave the internal bits unchanged.
      } else {
        // Undefined mode with an unknown/highZ selector.
        for (var i = 0; i < 4; i++) {
          state['q$i'] = SignalState.unknown;
        }
      }
    }

    return {
      9: state['q0'] ?? SignalState.unknown,
      10: state['q1'] ?? SignalState.unknown,
      11: state['q2'] ?? SignalState.unknown,
      12: state['q3'] ?? SignalState.unknown,
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
