import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS165 — 8-Bit Parallel-In / Serial-Out Shift Register.
///
/// DIP-16 pin layout (top view, notch up):
/// ```
///          +---\/---+
///   ~PL  1 |        | 16 VCC
///    CLK 2 |        | 15 CLK INH
///     E  3 |        | 14 D
///     F  4 | 74LS165| 13 C
///     G  5 |        | 12 B
///     H  6 |        | 11 A
///   ~QH  7 |        | 10 SER
///   GND  8 |________| 9  QH
/// ```
///
/// A low level on ~PL asynchronously loads parallel inputs A-H. While ~PL
/// is high, a rising edge on CLK with CLK INH low (or a rising edge on
/// CLK INH with CLK low) shifts the register toward H; SER enters the A
/// position and QH outputs the H position, with ~QH as its complement.
class Chip74LS165 extends ChipDefinition {
  @override
  String get model => '74LS165';

  @override
  String get description => '8 位\n并入串出寄存器';

  @override
  String get functionSummary => '八位并行输入、串行输出的移位寄存器；~PL 低电平异步'
      '载入 A~H，之后在 CLK（CLK INH 为低）或 CLK INH（CLK 为低）的上升沿向 H 方向'
      '移位，SER 进入最低位 A，QH 输出最高位 H 并提供互补输出 ~QH。';

  @override
  List<String> get datasheetNotes => const [
        '~PL 为低电平有效，载入优先级高于时钟；移位期间 ~PL 应保持高电平。',
        'CLK 与 CLK INH 组成或逻辑：其中一个上升沿到来且另一个为低电平时移位。',
        'SER 在移位时进入 A 位，数据逐级向 H 位移动，QH = H、~QH = /H。',
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
        'prev_inh': SignalState.unknown,
        for (var i = 0; i < 8; i++) 'q$i': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-8)
    PinDefinition(number: 1, label: '~PL', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'CLK', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'E', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'F', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'G', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'H', direction: PinDirection.input),
    PinDefinition(number: 7, label: '~QH', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 16-9)
    PinDefinition(number: 16, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 15, label: 'CLK INH', direction: PinDirection.input),
    PinDefinition(number: 14, label: 'D', direction: PinDirection.input),
    PinDefinition(number: 13, label: 'C', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'B', direction: PinDirection.input),
    PinDefinition(number: 11, label: 'A', direction: PinDirection.input),
    PinDefinition(number: 10, label: 'SER', direction: PinDirection.input),
    PinDefinition(number: 9, label: 'QH', direction: PinDirection.output),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final pl = _val(1, inputStates);
    final clock = _val(2, inputStates);
    final inh = _val(15, inputStates);
    final previousClock = state['prev_clk'] ?? SignalState.unknown;
    final previousInh = state['prev_inh'] ?? SignalState.unknown;
    state['prev_clk'] = clock;
    state['prev_inh'] = inh;

    if (pl == SignalState.low) {
      for (var i = 0; i < 8; i++) {
        final pin = i < 4 ? 11 + i : i - 1;
        final data = _val(pin, inputStates);
        state['q$i'] = data.isDriven ? data : SignalState.unknown;
      }
    } else {
      final clockEdge = clock == SignalState.high &&
          previousClock != SignalState.high &&
          inh == SignalState.low;
      final inhEdge = inh == SignalState.high &&
          previousInh != SignalState.high &&
          clock == SignalState.low;
      if (clockEdge || inhEdge) {
        final serial = _val(10, inputStates);
        final next = <int, SignalState>{
          for (var i = 0; i < 8; i++)
            i: state['q${i - 1}'] ?? SignalState.unknown,
        };
        next[0] = serial.isDriven ? serial : SignalState.unknown;
        for (var i = 0; i < 8; i++) {
          state['q$i'] = next[i]!;
        }
      }
    }

    final qh = state['q7'] ?? SignalState.unknown;
    return {
      9: qh,
      7: qh.not(),
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
