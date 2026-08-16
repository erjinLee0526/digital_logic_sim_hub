import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls244.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS244 chip;

  setUp(() => chip = Chip74LS244());

  group('Chip74LS244', () {
    test('has correct model number', () {
      expect(chip.model, '74LS244');
    });

    test('has the correct 20-pin layout', () {
      const expected = {
        1: ('~1G', 'input'),
        2: ('1A1', 'input'),
        3: ('2Y4', 'output'),
        4: ('1A2', 'input'),
        5: ('2Y3', 'output'),
        6: ('1A3', 'input'),
        7: ('2Y2', 'output'),
        8: ('1A4', 'input'),
        9: ('2Y1', 'output'),
        10: ('GND', 'ground'),
        11: ('2A1', 'input'),
        12: ('1Y4', 'output'),
        13: ('2A2', 'input'),
        14: ('1Y3', 'output'),
        15: ('2A3', 'input'),
        16: ('1Y2', 'output'),
        17: ('2A4', 'input'),
        18: ('1Y1', 'output'),
        19: ('~2G', 'input'),
        20: ('VCC', 'power'),
      };
      expect(chip.pinDefinitions.length, 20);
      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key}');
        expect(pin.direction.name, entry.value.$2, reason: 'pin ${entry.key}');
      }
    });

    test('each group passes its A inputs to the matching Y outputs', () {
      final result = chip.evaluate({
        1: SignalState.low, // ~1G enabled
        2: SignalState.low,
        4: SignalState.high,
        6: SignalState.low,
        8: SignalState.high,
        19: SignalState.low, // ~2G enabled
        11: SignalState.high,
        13: SignalState.low,
        15: SignalState.high,
        17: SignalState.low,
      });
      expect(result[18], SignalState.low); // 1Y1
      expect(result[16], SignalState.high); // 1Y2
      expect(result[14], SignalState.low); // 1Y3
      expect(result[12], SignalState.high); // 1Y4
      expect(result[9], SignalState.high); // 2Y1
      expect(result[7], SignalState.low); // 2Y2
      expect(result[5], SignalState.high); // 2Y3
      expect(result[3], SignalState.low); // 2Y4
    });

    test('a disabled group drives all its outputs to highZ', () {
      final result = chip.evaluate({
        1: SignalState.high, // ~1G disabled
        2: SignalState.high,
        4: SignalState.high,
        6: SignalState.high,
        8: SignalState.high,
        19: SignalState.low, // ~2G enabled
        11: SignalState.low,
      });
      for (final pin in const [18, 16, 14, 12]) {
        expect(result[pin], SignalState.highZ, reason: 'pin $pin');
      }
      expect(result[9], SignalState.low);
    });

    test('unknown enable makes only that group unknown', () {
      final result = chip.evaluate({
        1: SignalState.unknown,
        19: SignalState.low,
        11: SignalState.high,
      });
      for (final pin in const [18, 16, 14, 12]) {
        expect(result[pin], SignalState.unknown, reason: 'pin $pin');
      }
      expect(result[9], SignalState.high);
    });

    test('highZ data affects only its own output', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.highZ, // 1A1 floating
        4: SignalState.high,
        6: SignalState.low,
        8: SignalState.high,
      });
      expect(result[18], SignalState.unknown);
      expect(result[16], SignalState.high);
      expect(result[14], SignalState.low);
      expect(result[12], SignalState.high);
    });

    test('disabled group stays highZ even with floating data', () {
      final result = chip.evaluate({
        1: SignalState.high,
        2: SignalState.highZ,
      });
      for (final pin in const [18, 16, 14, 12]) {
        expect(result[pin], SignalState.highZ, reason: 'pin $pin');
      }
    });
  });
}
