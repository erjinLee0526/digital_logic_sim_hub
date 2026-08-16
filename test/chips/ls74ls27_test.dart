import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls27.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS27 chip;

  setUp(() => chip = Chip74LS27());

  group('Chip74LS27', () {
    test('has correct model number', () {
      expect(chip.model, '74LS27');
    });

    test('has the correct 14-pin layout', () {
      const expected = {
        1: ('1A', 'input'),
        2: ('1B', 'input'),
        3: ('2A', 'input'),
        4: ('2B', 'input'),
        5: ('2C', 'input'),
        6: ('2Y', 'output'),
        7: ('GND', 'ground'),
        8: ('3Y', 'output'),
        9: ('3A', 'input'),
        10: ('3B', 'input'),
        11: ('3C', 'input'),
        12: ('1Y', 'output'),
        13: ('1C', 'input'),
        14: ('VCC', 'power'),
      };
      expect(chip.pinDefinitions.length, 14);
      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key}');
        expect(pin.direction.name, entry.value.$2, reason: 'pin ${entry.key}');
      }
    });

    test('each 3-input NOR gate follows the full truth table', () {
      const gates = {
        '门 1': ([1, 2, 13], 12),
        '门 2': ([3, 4, 5], 6),
        '门 3': ([9, 10, 11], 8),
      };
      for (final gate in gates.entries) {
        final ins = gate.value.$1;
        for (var mask = 0; mask < 8; mask++) {
          final values = [
            for (var i = 0; i < 3; i++)
              (mask >> (2 - i)) & 1 == 1
                  ? SignalState.high
                  : SignalState.low,
          ];
          final expected = values.every((v) => v == SignalState.low)
              ? SignalState.high
              : SignalState.low;
          final result = chip.evaluate({
            ins[0]: values[0],
            ins[1]: values[1],
            ins[2]: values[2],
          });
          expect(result[gate.value.$2], expected,
              reason: '${gate.key} combo $mask');
        }
      }
    });

    test('high input dominates unknown (gives low output)', () {
      final result = chip.evaluate({
        1: SignalState.high,
        2: SignalState.unknown,
        13: SignalState.low,
      });
      expect(result[12], SignalState.low);
    });

    test('non-dominated unknown input gives unknown output', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.unknown,
        13: SignalState.low,
      });
      expect(result[12], SignalState.unknown);
    });

    test('highZ input gives unknown even with a high input', () {
      final result = chip.evaluate({
        1: SignalState.highZ,
        2: SignalState.high,
        13: SignalState.low,
      });
      expect(result[12], SignalState.unknown);
    });
  });
}
