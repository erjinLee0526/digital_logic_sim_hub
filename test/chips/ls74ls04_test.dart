import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls04.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS04 chip;

  setUp(() {
    chip = Chip74LS04();
  });

  group('Chip74LS04', () {
    test('has correct model number', () {
      expect(chip.model, '74LS04');
    });

    test('has 14 pins with the correct labels and directions', () {
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
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key} label');
        expect(pin.direction.name, entry.value.$2,
            reason: 'pin ${entry.key} direction');
      }
    });

    test('each inverter follows the truth table', () {
      const gates = {
        'Gate 1': (inA: 1, out: 2),
        'Gate 2': (inA: 3, out: 4),
        'Gate 3': (inA: 5, out: 6),
        'Gate 4': (inA: 9, out: 8),
        'Gate 5': (inA: 11, out: 10),
        'Gate 6': (inA: 13, out: 12),
      };
      for (final gate in gates.entries) {
        expect(
            chip
                .evaluate({gate.value.inA: SignalState.low})[gate.value.out],
            SignalState.high,
            reason: '${gate.key} 0 -> 1');
        expect(
            chip
                .evaluate({gate.value.inA: SignalState.high})[gate.value.out],
            SignalState.low,
            reason: '${gate.key} 1 -> 0');
      }
    });

    test('unknown input gives unknown output', () {
      final result = chip.evaluate({1: SignalState.unknown});
      expect(result[2], SignalState.unknown);
    });

    test('highZ input gives unknown output', () {
      final result = chip.evaluate({1: SignalState.highZ});
      expect(result[2], SignalState.unknown);
    });
  });
}
