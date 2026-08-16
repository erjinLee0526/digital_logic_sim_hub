import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS245 - Octal Bus Transceiver with 3-State Outputs (DIP-20).
///
/// Pin layout (top view, notch up):
/// ```
///          +---\/---+
///   DIR  1 |        | 20 VCC
///    A1  2 |        | 19 ~OE
///    A2  3 |        | 18 B1
///    A3  4 |        | 17 B2
///    A4  5 | 74LS245| 16 B3
///    A5  6 |        | 15 B4
///    A6  7 |        | 14 B5
///    A7  8 |        | 13 B6
///    A8  9 |        | 12 B7
///   GND 10 |________| 11 B8
/// ```
///
/// Eight bidirectional data channels A1↔B1 .. A8↔B8. With ~OE low, DIR
/// high passes A→B and DIR low passes B→A; ~OE high puts both sides into
/// high impedance.
///
/// Modeling note: this simulator's pin model has no `inout` direction, so
/// both A and B are declared as input-type pins. The side selected by DIR
/// acts as the data source and the other side is driven by `evaluate`.
class Chip74LS245 extends ChipDefinition {
  @override
  String get model => '74LS245';

  @override
  String get description => '八总线收发器\n双向三态\nDIR 方向控制';

  @override
  String get functionSummary =>
      '八位双向三态总线收发器：~OE 为低时工作，DIR 为高把 A 侧数据送到 '
      'B 侧（A→B），DIR 为低把 B 侧数据送到 A 侧（B→A）；~OE 为高时两侧'
      '全部呈高阻（highZ），用于总线隔离。';

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
    PinDefinition(number: 1, label: 'DIR', direction: PinDirection.input),
    PinDefinition(number: 2, label: 'A1', direction: PinDirection.input),
    PinDefinition(number: 3, label: 'A2', direction: PinDirection.input),
    PinDefinition(number: 4, label: 'A3', direction: PinDirection.input),
    PinDefinition(number: 5, label: 'A4', direction: PinDirection.input),
    PinDefinition(number: 6, label: 'A5', direction: PinDirection.input),
    PinDefinition(number: 7, label: 'A6', direction: PinDirection.input),
    PinDefinition(number: 8, label: 'A7', direction: PinDirection.input),
    PinDefinition(number: 9, label: 'A8', direction: PinDirection.input),
    PinDefinition(number: 10, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 20-11)
    PinDefinition(number: 20, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 19, label: '~OE', direction: PinDirection.input),
    PinDefinition(number: 18, label: 'B1', direction: PinDirection.input),
    PinDefinition(number: 17, label: 'B2', direction: PinDirection.input),
    PinDefinition(number: 16, label: 'B3', direction: PinDirection.input),
    PinDefinition(number: 15, label: 'B4', direction: PinDirection.input),
    PinDefinition(number: 14, label: 'B5', direction: PinDirection.input),
    PinDefinition(number: 13, label: 'B6', direction: PinDirection.input),
    PinDefinition(number: 12, label: 'B7', direction: PinDirection.input),
    PinDefinition(number: 11, label: 'B8', direction: PinDirection.input),
  ];

  static const _channels = [
    (a: 2, b: 18),
    (a: 3, b: 17),
    (a: 4, b: 16),
    (a: 5, b: 15),
    (a: 6, b: 14),
    (a: 7, b: 13),
    (a: 8, b: 12),
    (a: 9, b: 11),
  ];

  static const _allDataPins = [
    2, 3, 4, 5, 6, 7, 8, 9, 18, 17, 16, 15, 14, 13, 12, 11,
  ];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(
          name: '通道 A1↔B1',
          inputPins: [19, 1, 2],
          outputPins: [18],
        ),
      ];

  @override
  List<String> get datasheetNotes => const [
        'DIR 为高时 A→B（B 侧被驱动），DIR 为低时 B→A（A 侧被驱动）。',
        '~OE 为高时两侧全部呈高阻（highZ）；~OE 或 DIR 未知（X）时两侧输出未知。',
        '仿真模型：本仿真器没有 inout 引脚类型，A/B 两侧均建模为输入型引脚；DIR 决定数据源一侧，另一侧由芯片求值驱动。',
        '作为数据源一侧的引脚悬空（Z）时，被驱动一侧输出未知；总线冲突由仿真引擎检测。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    final dir = _val(1, inputStates);
    final oe = _val(19, inputStates);
    final allUnknown = {
      for (final pin in _allDataPins) pin: SignalState.unknown,
    };
    if (dir == SignalState.highZ || oe == SignalState.highZ) {
      return allUnknown;
    }
    if (oe == SignalState.unknown) return allUnknown;
    if (oe == SignalState.high) {
      return {for (final pin in _allDataPins) pin: SignalState.highZ};
    }
    if (dir == SignalState.unknown) return allUnknown;

    final result = <int, SignalState>{};
    for (final channel in _channels) {
      final sourcePin = dir == SignalState.high ? channel.a : channel.b;
      final targetPin = dir == SignalState.high ? channel.b : channel.a;
      final source = _val(sourcePin, inputStates);
      result[targetPin] =
          source == SignalState.highZ ? SignalState.unknown : source;
    }
    return result;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
