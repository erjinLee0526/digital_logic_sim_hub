import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS93 — 4-Bit Binary Counter (Divide-by-2 and Divide-by-8 Sections).
///
/// DIP-14 pin layout (top view, notch up):
/// ```
///          +---\/---+
///   CKB  1 |        | 14 CKA
/// R0(1)  2 |        | 13 NC
/// R0(2)  3 |        | 12 QA
///    NC  4 | 74LS93 | 11 QD
///   VCC  5 |        | 10 GND
///    NC  6 |        | 9  QB
///    NC  7 |________| 8  QC
/// ```
///
/// The chip contains an independent divide-by-2 stage (CKA toggles QA on a
/// high-to-low transition) and a divide-by-8 stage (CKB advances QB/QC/QD
/// through 0-7 on a high-to-low transition). Wiring QA to CKB produces a
/// full 4-bit binary counter. R0(1) and R0(2) both high asynchronously
/// clear all outputs. Pins 4, 6, 7, and 13 are NC and are not modeled.
class Chip74LS93 extends ChipDefinition {
  @override
  String get model => '74LS93';

  @override
  String get description => '4 位\n二进制计数器';

  @override
  String get functionSummary => '异步 4 位二进制计数器，由独立的 2 分频级（CKA→QA）与 '
      '8 分频级（CKB→QB/QC/QD）组成；把 QA 接到 CKB 即可构成 ÷16 二进制计数，'
      'R0(1)/R0(2) 同时为高时异步清零。';

  @override
  List<String> get datasheetNotes => const [
        'R0(1) 与 R0(2) 同时为高时异步清零，优先级高于两个时钟输入。',
        '计数发生在 CKA / CKB 的高到低跳变；两级各自独立计数。',
        '实际封装的 4、6、7、13 脚为 NC（空脚），当前引脚模型中未建模。',
      ];

  @override
  int get propagationDelayPs => 20000;

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  Map<String, SignalState> get initialState => const {
        'prev_cka': SignalState.unknown,
        'prev_ckb': SignalState.unknown,
        'qa': SignalState.unknown,
        'qb': SignalState.unknown,
        'qc': SignalState.unknown,
        'qd': SignalState.unknown,
      };

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-7; physical NC pins 4, 6, 7 are not modeled)
    PinDefinition(number: 1, label: 'CKB', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'R0(1)', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'R0(2)', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'VCC', direction: PinDirection.power),
    // Right side (pins 14-8; physical NC pin 13 is not modeled)
    PinDefinition(number: 14, label: 'CKA', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'QA', direction: PinDirection.output),
    PinDefinition(number: 11, label: 'QD', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'GND', direction: PinDirection.ground),
    PinDefinition(number: 9, label: 'QB', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'QC', direction: PinDirection.output),
  ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final state = internalState ?? <String, SignalState>{};
    final cka = _val(14, inputStates);
    final ckb = _val(1, inputStates);
    final previousCka = state['prev_cka'] ?? SignalState.unknown;
    final previousCkb = state['prev_ckb'] ?? SignalState.unknown;
    state['prev_cka'] = cka;
    state['prev_ckb'] = ckb;

    final reset = _val(2, inputStates) == SignalState.high &&
        _val(3, inputStates) == SignalState.high;

    if (reset) {
      state['qa'] = SignalState.low;
      state['qb'] = SignalState.low;
      state['qc'] = SignalState.low;
      state['qd'] = SignalState.low;
    } else {
      // Both sections count on a high-to-low transition.
      if (cka == SignalState.low && previousCka == SignalState.high) {
        state['qa'] = (state['qa'] ?? SignalState.unknown).not();
      }

      if (ckb == SignalState.low && previousCkb == SignalState.high) {
        final qb = state['qb'];
        final qc = state['qc'];
        final qd = state['qd'];
        if (qb != null &&
            qc != null &&
            qd != null &&
            qb.isDriven &&
            qc.isDriven &&
            qd.isDriven) {
          final value = (qd == SignalState.high ? 4 : 0) +
              (qc == SignalState.high ? 2 : 0) +
              (qb == SignalState.high ? 1 : 0);
          final next = (value + 1) % 8;
          state['qb'] = SignalState.fromBool((next & 1) != 0);
          state['qc'] = SignalState.fromBool((next & 2) != 0);
          state['qd'] = SignalState.fromBool((next & 4) != 0);
        } else {
          state['qb'] = SignalState.unknown;
          state['qc'] = SignalState.unknown;
          state['qd'] = SignalState.unknown;
        }
      }
    }

    return {
      12: state['qa'] ?? SignalState.unknown,
      9: state['qb'] ?? SignalState.unknown,
      8: state['qc'] ?? SignalState.unknown,
      11: state['qd'] ?? SignalState.unknown,
    };
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
