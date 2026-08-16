import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS90 — Decade Counter (Divide-by-2 and Divide-by-5 Sections).
///
/// DIP-14 pin layout (top view, notch up):
/// ```
///          +---\/---+
///   CKB  1 |        | 14 CKA
/// R0(1)  2 |        | 13 NC
/// R0(2)  3 |        | 12 QA
///    NC  4 | 74LS90 | 11 QD
///   VCC  5 |        | 10 GND
/// R9(1)  6 |        | 9  QB
/// R9(2)  7 |________| 8  QC
/// ```
///
/// The chip contains an independent divide-by-2 stage (CKA toggles QA) and
/// a divide-by-5 stage (CKB advances QB/QC/QD through 0-1-2-3-4-0). Wiring
/// QA to CKB with the clock on CKA produces the BCD 0-9 sequence. R0(1) and
/// R0(2) reset to 0000; R9(1) and R9(2) set to 1001 (9). Pins 4 and 13 are
/// not connected on the real package and are intentionally left unmodeled.
class Chip74LS90 extends ChipDefinition {
  @override
  String get model => '74LS90';

  @override
  String get description => '十进制\n计数器';

  @override
  String get functionSummary => '异步十进制计数器，由独立的 2 分频级（CKA→QA）与 5 分频级'
      '（CKB→QB/QC/QD）组成；将 QA 接到 CKB 即可按 BCD 码 0~9 循环计数，支持异步'
      '清零（R0）与置 9（R9）。';

  @override
  List<String> get datasheetNotes => const [
        'R0(1)、R0(2) 同时为高时异步清零为 0000；R9(1)、R9(2) 同时为高时异步置 9'
            '（1001），且本模型按数据手册约定让置 9 优先于清零。',
        '计数发生在 CKA / CKB 的高到低跳变；内部两级各自独立计数。',
        '实际封装的 4 脚与 13 脚为 NC（空脚），当前引脚模型中未建模。',
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
    // Left side (pins 1-7; physical NC pin 4 is not modeled)
    PinDefinition(number: 1, label: 'CKB', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'R0(1)', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'R0(2)', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 6, label: 'R9(1)', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'R9(2)', direction: PinDirection.input),
    // Right side (pins 14-8; physical NC pin 13 is not modeled)
    PinDefinition(number: 14, label: 'CKA', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'QA', direction: PinDirection.output),
    PinDefinition(number: 11, label: 'QD', direction: PinDirection.output),
    PinDefinition(number: 9, label: 'QB', direction: PinDirection.output),
    PinDefinition(number: 8, label: 'QC', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'GND', direction: PinDirection.ground),
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

    final setToNine = _val(6, inputStates) == SignalState.high &&
        _val(7, inputStates) == SignalState.high;
    final resetToZero = _val(2, inputStates) == SignalState.high &&
        _val(3, inputStates) == SignalState.high;

    if (setToNine) {
      state['qa'] = SignalState.high;
      state['qb'] = SignalState.low;
      state['qc'] = SignalState.low;
      state['qd'] = SignalState.high;
    } else if (resetToZero) {
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
          final next = (value + 1) % 5;
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
