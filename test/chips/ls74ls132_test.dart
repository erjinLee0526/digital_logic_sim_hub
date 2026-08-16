import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls132.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS132 chip;

  setUp(() => chip = Chip74LS132());

  const gates = [
    (a: 1, b: 2, y: 3),
    (a: 4, b: 5, y: 6),
    (a: 9, b: 10, y: 8),
    (a: 12, b: 13, y: 11),
  ];

  group('Chip74LS132', () {
    test('has correct model number', () {
      expect(chip.model, '74LS132');
    });

    test('has the correct 14-pin layout', () {
      const expected = {
        1: ('1A', 'input'),
        2: ('1B', 'input'),
        3: ('1Y', 'output'),
        4: ('2A', 'input'),
        5: ('2B', 'input'),
        6: ('2Y', 'output'),
        7: ('GND', 'ground'),
        8: ('3Y', 'output'),
        9: ('3A', 'input'),
        10: ('3B', 'input'),
        11: ('4Y', 'output'),
        12: ('4A', 'input'),
        13: ('4B', 'input'),
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

    test('each gate follows the full NAND truth table', () {
      const cases = [
        (SignalState.low, SignalState.low, SignalState.high),
        (SignalState.low, SignalState.high, SignalState.high),
        (SignalState.high, SignalState.low, SignalState.high),
        (SignalState.high, SignalState.high, SignalState.low),
      ];
      for (final gate in gates) {
        for (final (a, b, expected) in cases) {
          expect(chip.evaluate({gate.a: a, gate.b: b})[gate.y], expected,
              reason: 'gate ${gates.indexOf(gate) + 1}: $a NAND $b');
        }
      }
    });

    test('low input dominates unknown (gives high output)', () {
      expect(
        chip.evaluate({1: SignalState.low, 2: SignalState.unknown})[3],
        SignalState.high,
      );
    });

    test('non-dominated unknown input gives unknown output', () {
      expect(
        chip.evaluate({1: SignalState.high, 2: SignalState.unknown})[3],
        SignalState.unknown,
      );
    });

    test('highZ input gives unknown even with a low input', () {
      expect(
        chip.evaluate({1: SignalState.low, 2: SignalState.highZ})[3],
        SignalState.unknown,
      );
    });

    test('the four gates are independent', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.low, // -> 1Y high
        4: SignalState.high,
        5: SignalState.high, // -> 2Y low
        9: SignalState.high,
        10: SignalState.high, // -> 3Y low
        12: SignalState.low,
        13: SignalState.high, // -> 4Y high
      });
      expect(result[3], SignalState.high);
      expect(result[6], SignalState.low);
      expect(result[8], SignalState.low);
      expect(result[11], SignalState.high);
    });
  });
}
