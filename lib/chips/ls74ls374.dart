import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS374 — Octal D-Type Positive-Edge-Triggered Flip-Flop with 3-State
/// Outputs (DIP-20).
///
/// Physical pin layout (top view, notch up):
/// ```
///            +---\/---+
///    ~OE  1 |         | 20 VCC
///    Q0   2 |         | 19 Q7
///    D0   3 |         | 18 D7
///    D1   4 |         | 17 D6
///    Q1   5 | 74LS374 | 16 Q6
///    Q2   6 |         | 15 Q5
///    D2   7 |         | 14 D5
///    D3   8 |         | 13 D4
///    Q3   9 |         | 12 Q4
///    GND 10 |_________| 11 CP
/// ```
///
/// The common CP input loads all eight D inputs on its rising edge,
/// regardless of ~OE. A low level on ~OE drives Q0~Q7 with the stored
/// values; a high level puts every output in high impedance without
/// disturbing the flip-flops.
class Chip74LS374 extends ChipDefinition {
  @override
  String get model => '74LS374';

  @override
  String get description => '八 D 触发器\n三态输出';

  @override
  String get functionSummary => '八路上升沿触发的 D 触发器，共用时钟 CP 与三态输出使能 ~OE；'
      'CP 上升沿锁存 D0~D7，~OE 低电平时输出 Q0~Q7，高电平时全部输出高阻。';

  @override
  List<String> get datasheetNotes => const [
        '仅当 CP 从非高电平变为高电平时采样 D0~D7；~OE 只控制输出，不影响内部锁存值。',
        '~OE 为高电平时 Q0~Q7 输出高阻（highZ），为低电平时输出已锁存的值。',
      ];

  @override
  int get propagationDelayPs => 20000;

  @override
  double get width => 100;

  @override
  double get height => 220;

  @override
  Map<String, SignalState> get initialState => {
        'prev_clk': SignalState.unknown,
        for (var i = 0; i < 8; i++) 'q$i': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-10)
    PinDefinition(number: 1, label: '~OE', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'Q0', direction: PinDirection.output),
    PinDefinition(number: 3, label: 'D0', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'D1', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'Q1', direction: PinDirection.output),
    PinDefinition(number: 6, label: 'Q2', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'D2', direction: PinDirection.input),
    PinDefinition(number: 8, label: 'D3', direction: PinDirection.input),
    PinDefinition(number: 9, label: 'Q3', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 20-11)
    PinDefinition(number: 20, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 19, label: 'Q7', direction: PinDirection.output),
    PinDefinition(number: 18, label: 'D7', direction: PinDirection.input),
    PinDefinition(number: 17, label: 'D6', direction: PinDirection.input),
    PinDefinition(number: 16, label: 'Q6', direction: PinDirection.output),
    PinDefinition(number: 15, label: 'Q5', direction: PinDirection.output),
    PinDefinition(number: 14, label: 'D5', direction: PinDirection.input),
    PinDefinition(number: 13, label: 'D4', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'Q4', direction: PinDirection.output),
    PinDefinition(number: 11, label: 'CP', direction: PinDirection.input),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final oe = _val(1, inputStates);
    final clock = _val(11, inputStates);
    final previousClock = state['prev_clk'] ?? SignalState.unknown;
    state['prev_clk'] = clock;

    if (clock == SignalState.high && previousClock != SignalState.high) {
      // D pin, bit index.
      const flipFlops = [
        (3, 0),
        (4, 1),
        (7, 2),
        (8, 3),
        (13, 4),
        (14, 5),
        (17, 6),
        (18, 7),
      ];
      for (final (dPin, bit) in flipFlops) {
        final data = _val(dPin, inputStates);
        state['q$bit'] = data.isDriven ? data : SignalState.unknown;
      }
    }

    final result = <int, SignalState>{};
    const qPins = [2, 5, 6, 9, 12, 15, 16, 19];
    for (var bit = 0; bit < 8; bit++) {
      final stored = state['q$bit'] ?? SignalState.unknown;
      if (oe == SignalState.low) {
        result[qPins[bit]] = stored;
      } else if (oe == SignalState.high) {
        result[qPins[bit]] = SignalState.highZ;
      } else {
        result[qPins[bit]] = SignalState.unknown;
      }
    }

    return result;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
