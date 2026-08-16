import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS166 — 8-Bit Parallel-In / Serial-Out Shift Register (DIP-16).
///
/// Physical pin layout (top view, notch up):
/// ```text
///          +---\/---+
///    SER  1 |        | 16 VCC
///     A   2 |        | 15 ~SH/LD
///     B   3 |        | 14 QH
///     C   4 | 74LS166| 13 H
///     D   5 |        | 12 G
/// CLK INH 6 |        | 11 F
///    CLK  7 |        | 10 E
///    GND  8 |________| 9  ~CLR
/// ```
///
/// A low level on ~CLR asynchronously clears all eight stages. While ~CLR
/// is high, a rising edge of CLK with CLK INH high either loads A~H in
/// parallel (~SH/LD low) or shifts one position toward QH (~SH/LD high),
/// with SER entering the first stage.
class Chip74LS166 extends ChipDefinition {
  @override
  String get model => '74LS166';

  @override
  String get description => '8 位\n并入串出寄存器';

  @override
  String get functionSummary => '八位并行输入、串行输出的移位寄存器；~CLR 低电平异步清零，'
      'CLK INH 为高时 CLK 上升沿生效，~SH/LD 为低时并行置入 A~H、为高时向 QH 方向'
      '移位并由 SER 进入最低位。';

  @override
  List<String> get datasheetNotes => const [
        '~CLR 为低电平有效且优先级最高，异步清零全部八级，QH 立即为低。',
        'CLK INH 为低电平时时钟被禁止，寄存器保持；为高电平时 CLK 上升沿触发。',
        '~SH/LD 为低时在下一个 CLK 上升沿同步并行置入 A~H，为高时右移、SER 进入最低位。',
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
        for (var i = 0; i < 8; i++) 'q$i': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: 'SER', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'A', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'B', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'C', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'D', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'CLK INH', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'CLK', direction: PinDirection.input),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: '~SH/LD', direction: PinDirection.input),
    PinDefinition(number: 14, label: 'QH', direction: PinDirection.output),
    PinDefinition(number: 13, label: 'H', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'G', direction: PinDirection.input),
    PinDefinition(number: 11, label: 'F', direction: PinDirection.input),
    PinDefinition(number: 10, label: 'E', direction: PinDirection.input),
    PinDefinition(number: 9, label: '~CLR', direction: PinDirection.input),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final clr = _val(9, inputStates);
    final shLd = _val(15, inputStates);
    final clock = _val(7, inputStates);
    final inh = _val(6, inputStates);
    final previousClock = state['prev_clk'] ?? SignalState.unknown;
    state['prev_clk'] = clock;

    if (clr == SignalState.low) {
      for (var i = 0; i < 8; i++) {
        state['q$i'] = SignalState.low;
      }
    } else if (clock == SignalState.high &&
        previousClock != SignalState.high &&
        inh == SignalState.high) {
      if (shLd == SignalState.low) {
        _load(state, inputStates);
      } else if (shLd == SignalState.high) {
        _shift(state, inputStates);
      }
      // Unknown or highZ ~SH/LD: hold the current value.
    }

    return {
      14: state['q7'] ?? SignalState.unknown,
    };
  }

  static void _load(
    Map<String, SignalState> state,
    Map<int, SignalState> inputStates,
  ) {
    // A=2, B=3, C=4, D=5, E=10, F=11, G=12, H=13.
    const dataPins = [2, 3, 4, 5, 10, 11, 12, 13];
    for (var i = 0; i < 8; i++) {
      final data = inputStates[dataPins[i]] ?? SignalState.unknown;
      state['q$i'] = data.isDriven ? data : SignalState.unknown;
    }
  }

  static void _shift(
    Map<String, SignalState> state,
    Map<int, SignalState> inputStates,
  ) {
    final serial = inputStates[1] ?? SignalState.unknown;
    for (var i = 7; i >= 1; i--) {
      state['q$i'] = state['q${i - 1}'] ?? SignalState.unknown;
    }
    state['q0'] = serial.isDriven ? serial : SignalState.unknown;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
