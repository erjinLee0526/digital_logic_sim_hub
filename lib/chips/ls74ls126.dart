import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';

/// 74LS126 - Quad Bus Buffer with 3-State Outputs, Active-High Enables (DIP-14).
///
/// Pin layout (top view, notch up):
/// ```
///         +---\/---+
///   1G  1 |        | 14  VCC
///   1A  2 |        | 13  4G
///   1Y  3 |        | 12  4A
///   2G  4 |        | 11  4Y
///   2A  5 | 74LS126 | 10  3G
///   2Y  6 |        | 9   3A
///  GND  7 |________| 8   3Y
/// ```
///
/// Four independent non-inverting buffers, each with its own active-high
/// enable. Enabled (G high): Y follows A. Disabled (G low): Y goes to high
/// impedance so several outputs can share one bus. Same pinout as 74LS125
/// but with inverted enable polarity.
class Chip74LS126 extends ChipDefinition {
  @override
  String get model => '74LS126';

  @override
  String get description => '四总线缓冲器\n三态输出\n独立高有效使能';

  @override
  String get functionSummary =>
      '四个独立的三态总线缓冲器（不反相）。每个缓冲器的使能 G 为高时 '
      'Y 跟随 A；G 为低时 Y 呈高阻（highZ），允许多个输出共享同一条'
      '总线。与 74LS125 引脚相同，但使能极性相反（高有效）。';

  @override
  int get propagationDelayPs => 12000; // ~12ns typical

  @override
  double get width => 80;

  @override
  double get height => 160;

  @override
  List<PinDefinition> get pinDefinitions => _pins;

  static const _pins = [
    // Left side (pins 1-7)
    PinDefinition(number: 1, label: '1G', direction: PinDirection.input),
    PinDefinition(number: 2, label: '1A', direction: PinDirection.input),
    PinDefinition(number: 3, label: '1Y', direction: PinDirection.output),
    PinDefinition(number: 4, label: '2G', direction: PinDirection.input),
    PinDefinition(number: 5, label: '2A', direction: PinDirection.input),
    PinDefinition(number: 6, label: '2Y', direction: PinDirection.output),
    PinDefinition(number: 7, label: 'GND', direction: PinDirection.ground),
    // Right side (pins 14-8)
    PinDefinition(number: 14, label: 'VCC', direction: PinDirection.power),
    PinDefinition(number: 13, label: '4G', direction: PinDirection.input),
    PinDefinition(number: 12, label: '4A', direction: PinDirection.input),
    PinDefinition(number: 11, label: '4Y', direction: PinDirection.output),
    PinDefinition(number: 10, label: '3G', direction: PinDirection.input),
    PinDefinition(number: 9, label: '3A', direction: PinDirection.input),
    PinDefinition(number: 8, label: '3Y', direction: PinDirection.output),
  ];

  static const _buffers = [
    (enable: 1, a: 2, y: 3),
    (enable: 4, a: 5, y: 6),
    (enable: 10, a: 9, y: 8),
    (enable: 13, a: 12, y: 11),
  ];

  @override
  List<TruthTableGroup> get truthTableGroups => const [
        TruthTableGroup(name: '缓冲器 1', inputPins: [1, 2], outputPins: [3]),
        TruthTableGroup(name: '缓冲器 2', inputPins: [4, 5], outputPins: [6]),
        TruthTableGroup(name: '缓冲器 3', inputPins: [10, 9], outputPins: [8]),
        TruthTableGroup(name: '缓冲器 4', inputPins: [13, 12], outputPins: [11]),
      ];

  @override
  List<String> get datasheetNotes => const [
        '使能 G 为高时 Y 跟随 A（不反相）；G 为低时 Y 呈高阻（highZ）。',
        '使能未知（X）时输出未知；使能为高且数据悬空（Z）时输出未知。',
        '多路输出可并接到同一条总线，总线冲突由仿真引擎检测。',
      ];

  @override
  Map<int, SignalState> evaluate(
    Map<int, SignalState> inputStates, {
    Map<String, SignalState>? internalState,
  }) {
    return {
      for (final buffer in _buffers)
        buffer.y: _bufferOut(
          _val(buffer.enable, inputStates),
          _val(buffer.a, inputStates),
        ),
    };
  }

  static SignalState _bufferOut(SignalState enable, SignalState a) {
    if (enable == SignalState.highZ) return SignalState.unknown;
    if (enable == SignalState.unknown) return SignalState.unknown;
    if (enable == SignalState.low) return SignalState.highZ;
    if (a == SignalState.highZ) return SignalState.unknown;
    return a;
  }

  static SignalState _val(int pinNum, Map<int, SignalState> states) {
    return states[pinNum] ?? SignalState.unknown;
  }
}
