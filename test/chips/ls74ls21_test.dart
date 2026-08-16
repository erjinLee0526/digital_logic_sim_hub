import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls21.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS21 chip;

  setUp(() => chip = Chip74LS21());

  group('Chip74LS21', () {
    test('has correct model number', () {
      expect(chip.model, '74LS21');
    });

    test('has 12 modeled pins (pins 3 and 11 are NC)', () {
      const expected = {
        1: ('1A', 'input'),
        2: ('1B', 'input'),
        4: ('1C', 'input'),
        5: ('1D', 'input'),
        6: ('1Y', 'output'),
        7: ('GND', 'ground'),
        8: ('2Y', 'output'),
        9: ('2A', 'input'),
        10: ('2B', 'input'),
        12: ('2C', 'input'),
        13: ('2D', 'input'),
        14: ('VCC', 'power'),
      };
      expect(chip.pinDefinitions.length, 12);
      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key}');
        expect(pin.direction.name, entry.value.$2, reason: 'pin ${entry.key}');
      }
      expect(chip.datasheetNotes.any((n) => n.contains('NC')), isTrue);
    });

    test('each 4-input AND gate follows the full truth table', () {
      const gates = {
        '门 1': ([1, 2, 4, 5], 6),
        '门 2': ([9, 10, 12, 13], 8),
      };
      for (final gate in gates.entries) {
        final ins = gate.value.$1;
        for (var mask = 0; mask < 16; mask++) {
          final values = [
            for (var i = 0; i < 4; i++)
              (mask >> (3 - i)) & 1 == 1
                  ? SignalState.high
                  : SignalState.low,
          ];
          final expected = values.every((v) => v == SignalState.high)
              ? SignalState.high
              : SignalState.low;
          final result = chip.evaluate({
            ins[0]: values[0],
            ins[1]: values[1],
            ins[2]: values[2],
            ins[3]: values[3],
          });
          expect(result[gate.value.$2], expected,
              reason: '${gate.key} combo $mask');
        }
      }
    });

    test('low input dominates unknown (gives low output)', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.unknown,
        4: SignalState.high,
        5: SignalState.high,
      });
      expect(result[6], SignalState.low);
    });

    test('non-dominated unknown input gives unknown output', () {
      final result = chip.evaluate({
        1: SignalState.high,
        2: SignalState.unknown,
        4: SignalState.high,
        5: SignalState.high,
      });
      expect(result[6], SignalState.unknown);
    });

    test('highZ input gives unknown even with a low input', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.highZ,
        4: SignalState.high,
        5: SignalState.high,
      });
      expect(result[6], SignalState.unknown);
    });
  });
}
