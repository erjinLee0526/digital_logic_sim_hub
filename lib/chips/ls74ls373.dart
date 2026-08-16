import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS373 — Octal Transparent Latch with 3-State Outputs.
///
/// DIP-20 pin layout (top view, notch up):
/// ```
///          +---\/---+
///   ~OE  1 |        | 20 VCC
///   1Q   2 |        | 19 8Q
///   1D   3 |        | 18 8D
///   2D   4 |        | 17 7D
///   2Q   5 |        | 16 7Q
///   3Q   6 |        | 15 6Q
///   3D   7 |        | 14 6D
///   4D   8 |        | 13 5D
///   4Q   9 |        | 12 5Q
///   GND 10 |________| 11 LE
/// ```
///
/// When LE is high the eight latches are transparent. When LE goes low the
/// current data is captured. ~OE low enables the 3-state outputs; ~OE high
/// puts every Q output into high impedance.
class Chip74LS373 extends ChipDefinition {
  @override
  String get model => '74LS373';

  @override
  String get description => '8 位\n透明锁存器';

  @override
  String get functionSummary => '八位透明 D 锁存器：LE 为高电平时 Q 跟随 D，LE 降为低电平时'
      '锁存当前数据；~OE 为低电平时输出有效，为高电平时所有 Q 输出呈高阻。';

  @override
  List<String> get datasheetNotes => const [
        'LE 为高电平有效；锁存发生在 LE 从高到低的跳变。',
        '~OE 为低电平有效；输出被禁止时进入 highZ，内部锁存值仍会保持。',
      ];

  @override
  int get propagationDelayPs => 15000;

  @override
  double get width => 100;

  @override
  double get height => 220;

  @override
  Map<String, SignalState> get initialState => {
        for (var i = 0; i < 8; i++) 'q$i': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-10)
    PinDefinition(number: 1, label: '~OE', direction: PinDirection.input),
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
    PinDefinition(number: 11, label: 'LE', direction: PinDirection.input),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final oe = _val(1, inputStates);
    final le = _val(11, inputStates);
    final result = <int, SignalState>{};

    // Bit index, D pin, Q pin.
    const bits = [
      (3, 2),
      (4, 5),
      (7, 6),
      (8, 9),
      (13, 12),
      (14, 15),
      (17, 16),
      (18, 19),
    ];

    for (var i = 0; i < bits.length; i++) {
      final (dPin, qPin) = bits[i];
      final key = 'q$i';
      final data = _val(dPin, inputStates);

      // Keep the latch current even while the outputs are disabled.
      if (le == SignalState.high) {
        state[key] = data.isDriven ? data : SignalState.unknown;
      }

      if (oe == SignalState.high) {
        result[qPin] = SignalState.highZ;
      } else if (oe == SignalState.low) {
        if (le == SignalState.high || le == SignalState.low) {
          result[qPin] = state[key] ?? SignalState.unknown;
        } else {
          result[qPin] = SignalState.unknown;
        }
      } else {
        result[qPin] = SignalState.unknown;
      }
    }

    return result;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
