import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls14.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS14 chip;

  setUp(() => chip = Chip74LS14());

  const gates = [
    (a: 1, y: 2),
    (a: 3, y: 4),
    (a: 5, y: 6),
    (a: 9, y: 8),
    (a: 11, y: 10),
    (a: 13, y: 12),
  ];

  group('Chip74LS14', () {
    test('has correct model number', () {
      expect(chip.model, '74LS14');
    });

    test('has the correct 14-pin layout', () {
      const expected = {
        1: ('1A', 'input'),
        2: ('1Y', 'output'),
        3: ('2A', 'input'),
        4: ('2Y', 'output'),
        5: ('3A', 'input'),
        6: ('3Y', 'output'),
        7: ('GND', 'ground'),
        8: ('4Y', 'output'),
        9: ('4A', 'input'),
        10: ('5Y', 'output'),
        11: ('5A', 'input'),
        12: ('6Y', 'output'),
        13: ('6A', 'input'),
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

    test('each inverter follows the truth table', () {
      for (final gate in gates) {
        expect(chip.evaluate({gate.a: SignalState.low})[gate.y],
            SignalState.high,
            reason: 'gate ${gates.indexOf(gate) + 1}, input low');
        expect(chip.evaluate({gate.a: SignalState.high})[gate.y],
            SignalState.low,
            reason: 'gate ${gates.indexOf(gate) + 1}, input high');
      }
    });

    test('the six inverters are independent', () {
      final result = chip.evaluate({
        1: SignalState.low,
        3: SignalState.high,
        5: SignalState.low,
        9: SignalState.high,
        11: SignalState.low,
        13: SignalState.high,
      });
      expect(result[2], SignalState.high);
      expect(result[4], SignalState.low);
      expect(result[6], SignalState.high);
      expect(result[8], SignalState.low);
      expect(result[10], SignalState.high);
      expect(result[12], SignalState.low);
    });

    test('unknown input gives unknown output', () {
      expect(chip.evaluate({1: SignalState.unknown})[2], SignalState.unknown);
    });

    test('highZ input gives unknown output', () {
      expect(chip.evaluate({1: SignalState.highZ})[2], SignalState.unknown);
    });
  });
}
