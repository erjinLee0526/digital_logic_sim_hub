import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls04.dart';
import 'package:digital_logic_sim/chips/ls74ls08.dart';
import 'package:digital_logic_sim/chips/ls74ls266.dart';
import 'package:digital_logic_sim/models/chip_definition.dart';
import 'package:digital_logic_sim/models/signal_state.dart';
import 'package:digital_logic_sim/models/truth_table.dart';

void main() {
  group('generateTruthTable', () {
    test('enumerates a 2-input AND gate in standard order', () {
      final chip = Chip74LS08();
      const group = TruthTableGroup(
        name: 'Gate 1',
        inputPins: [1, 2],
        outputPins: [3],
      );

      final rows = generateTruthTable(chip, group);

      expect(rows.length, 4);
      expect(
        rows.map((r) => r.inputs.map((s) => s.displayName).join()).toList(),
        ['00', '01', '10', '11'],
      );
      expect(
        rows.map((r) => r.outputs.single).toList(),
        [
          SignalState.low,
          SignalState.low,
          SignalState.low,
          SignalState.high,
        ],
      );
    });

    test('enumerates a single-input inverter', () {
      final chip = Chip74LS04();
      const group = TruthTableGroup(
        name: 'Gate 1',
        inputPins: [1],
        outputPins: [2],
      );

      final rows = generateTruthTable(chip, group);

      expect(rows.length, 2);
      expect(rows[0].outputs.single, SignalState.high);
      expect(rows[1].outputs.single, SignalState.low);
    });

    test('open-collector XNOR shows highZ for logic-1 outputs', () {
      final chip = Chip74LS266();
      const group = TruthTableGroup(
        name: 'Gate 1',
        inputPins: [1, 2],
        outputPins: [3],
      );

      final rows = generateTruthTable(chip, group);

      expect(rows[0].outputs.single, SignalState.highZ);
      expect(rows[1].outputs.single, SignalState.low);
      expect(rows[2].outputs.single, SignalState.low);
      expect(rows[3].outputs.single, SignalState.highZ);
    });
  });
}
