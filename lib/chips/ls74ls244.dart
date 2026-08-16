import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS244 - Octal Buffer/Line Driver with 3-State Outputs (DIP-20).
///
/// Pin layout (top view, notch up):
/// ```
///          +---\/---+
///   ~1G  1 |        | 20 VCC
///   1A1  2 |        | 19 ~2G
///   2Y4  3 |        | 18 1Y1
///   1A2  4 |        | 17 2A4
///   2Y3  5 |        | 16 1Y2
///   1A3  6 | 74LS244| 15 2A3
///   2Y2  7 |        | 14 1Y3
///   1A4  8 |        | 13 2A2
///   2Y1  9 |        | 12 1Y4
///   GND 10 |________| 11 2A1
/// ```
///
/// Eight non-inverting buffers in two groups of four, enabled by ~1G and
/// ~2G respectively. Enabled: Y follows A. Disabled: every Y of that group
/// goes to high impedance.
class Chip74LS244 extends ChipDefinition {
  @override
  String get model => '74LS244';

  @override
  String get description => '八缓冲/线驱动\n三态输出\n两组四路';

  @override
  String get functionSummary =>
      '八路三态总线缓冲器（不反相），分为两组四路：~1G 控制 1A1–1A4 → '
      '1Y1–1Y4，~2G 控制 2A1–2A4 → 2Y1–2Y4。使能为低时 Y 跟随 A，为高时'
      '该组输出全部呈高阻（highZ）。';

  @override
  int get propagationDelayPs => 12000; // ~12ns typical

  @override
  double get width => 100;

  @override
  double get height => 220;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-10)
    PinDefinition(number: 1, label: '~1G', direction: PinDirection.input),
    PinDefinition(number: 2, label: '1A1', direction: PinDirection.input),
    PinDefinition(number: 3, label: '2Y4', direction: PinDirection.output),
    PinDefinition(number: 4, label: '1A2', direction: PinDirection.input),
    PinDefinition(number: 5, label: '2Y3', direction: PinDirection.output),
    PinDefinition(number: 6, label: '1A3', direction: PinDirection.input),
    PinDefinition(number: 7, label: '2Y2', direction: PinDirection.output),
    PinDefinition(number: 8, label: '1A4', direction: PinDirection.input),
    PinDefinition(number: 9, label: '2Y1', direction: PinDirection.output),
    PinDefinition(number: 10, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 20-11)
    PinDefinition(number: 20, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 19, label: '~2G', direction: PinDirection.input),
    PinDefinition(number: 18, label: '1Y1', direction: PinDirection.output),
    PinDefinition(number: 17, label: '2A4', direction: PinDirection.input),
    PinDefinition(number: 16, label: '1Y2', direction: PinDirection.output),
    PinDefinition(number: 15, label: '2A3', direction: PinDirection.input),
    PinDefinition(number: 14, label: '1Y3', direction: PinDirection.output),
    PinDefinition(number: 13, label: '2A2', direction: PinDirection.input),
    PinDefinition(number: 12, label: '1Y4', direction: PinDirection.output),
    PinDefinition(number: 11, label: '2A1', direction: PinDirection.input),
  ];

  static const _group1 = [
    (a: 2, y: 18),
    (a: 4, y: 16),
    (a: 6, y: 14),
    (a: 8, y: 12),
  ];
  static const _group2 = [
    (a: 11, y: 9),
    (a: 13, y: 7),
    (a: 15, y: 5),
    (a: 17, y: 3),
  ];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(
          name: '缓冲组 1（~1G）',
          inputPins: [1, 2, 4, 6, 8],
          outputPins: [18, 16, 14, 12],
        ),
        TruthTableGroup(
          name: '缓冲组 2（~2G）',
          inputPins: [19, 11, 13, 15, 17],
          outputPins: [9, 7, 5, 3],
        ),
      ];

  @override
  List<String> get datasheetNotes => const [
        '使能 ~G 为低时该组 Y 跟随对应 A（不反相）；~G 为高时该组输出全部呈高阻（highZ）。',
        '使能未知（X）时该组输出未知；使能为低且数据悬空（Z）时该路输出未知。',
        '多路输出可并接到同一条总线，总线冲突由仿真引擎检测。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final g1 = _val(1, inputStates);
    final g2 = _val(19, inputStates);
    return {
      for (final buffer in _group1)
        buffer.y: _bufferOut(g1, _val(buffer.a, inputStates)),
      for (final buffer in _group2)
        buffer.y: _bufferOut(g2, _val(buffer.a, inputStates)),
    };
  }

  static SignalState _bufferOut(SignalState enable, SignalState a) {
    if (enable == SignalState.highZ) return SignalState.unknown;
    if (enable == SignalState.unknown) return SignalState.unknown;
    if (enable == SignalState.high) return SignalState.highZ;
    if (a == SignalState.highZ) return SignalState.unknown;
    return a;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
