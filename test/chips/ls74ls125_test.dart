import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls125.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS125 chip;

  setUp(() => chip = Chip74LS125());

  group('Chip74LS125', () {
    test('has correct model number', () {
      expect(chip.model, '74LS125');
    });

    test('has the correct 14-pin layout', () {
      const expected = {
        1: ('~1G', 'input'),
        2: ('1A', 'input'),
        3: ('1Y', 'output'),
        4: ('~2G', 'input'),
        5: ('2A', 'input'),
        6: ('2Y', 'output'),
        7: ('GND', 'ground'),
        8: ('3Y', 'output'),
        9: ('3A', 'input'),
        10: ('~3G', 'input'),
        11: ('4Y', 'output'),
        12: ('4A', 'input'),
        13: ('~4G', 'input'),
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

    test('enabled buffers pass A through to Y', () {
      const buffers = [
        (enable: 1, a: 2, y: 3),
        (enable: 4, a: 5, y: 6),
        (enable: 10, a: 9, y: 8),
        (enable: 13, a: 12, y: 11),
      ];
      for (final level in [SignalState.low, SignalState.high]) {
        final inputs = <int, SignalState>{};
        for (final buffer in buffers) {
          inputs[buffer.enable] = SignalState.low;
          inputs[buffer.a] = level;
        }
        final result = chip.evaluate(inputs);
        for (final buffer in buffers) {
          expect(result[buffer.y], level, reason: 'Y${buffers.indexOf(buffer) + 1}');
        }
      }
    });

    test('disabled buffer output is high impedance', () {
      final result = chip.evaluate({1: SignalState.high, 2: SignalState.high});
      expect(result[3], SignalState.highZ);
    });

    test('buffers are independent', () {
      final result = chip.evaluate({
        1: SignalState.low, // 1 enabled
        2: SignalState.high, // 1A
        4: SignalState.high, // 2 disabled
        5: SignalState.low, // 2A
        10: SignalState.low, // 3 enabled
        9: SignalState.low, // 3A
        13: SignalState.high, // 4 disabled
        12: SignalState.high, // 4A
      });
      expect(result[3], SignalState.high);
      expect(result[6], SignalState.highZ);
      expect(result[8], SignalState.low);
      expect(result[11], SignalState.highZ);
    });

    test('unknown enable makes that output unknown', () {
      final result = chip.evaluate({1: SignalState.unknown, 2: SignalState.high});
      expect(result[3], SignalState.unknown);
    });

    test('highZ enable makes that output unknown', () {
      final result = chip.evaluate({1: SignalState.highZ, 2: SignalState.high});
      expect(result[3], SignalState.unknown);
    });

    test('highZ data while enabled makes that output unknown', () {
      final result = chip.evaluate({1: SignalState.low, 2: SignalState.highZ});
      expect(result[3], SignalState.unknown);
    });

    test('unknown data while enabled passes through as unknown', () {
      final result = chip.evaluate({1: SignalState.low, 2: SignalState.unknown});
      expect(result[3], SignalState.unknown);
    });

    test('disabled output stays highZ even with floating data', () {
      final result = chip.evaluate({1: SignalState.high, 2: SignalState.highZ});
      expect(result[3], SignalState.highZ);
    });
  });
}
