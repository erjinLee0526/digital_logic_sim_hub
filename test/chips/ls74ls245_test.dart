import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls245.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS245 chip;

  setUp(() => chip = Chip74LS245());

  const aPins = [2, 3, 4, 5, 6, 7, 8, 9];
  const bPins = [18, 17, 16, 15, 14, 13, 12, 11];

  group('Chip74LS245', () {
    test('has correct model number', () {
      expect(chip.model, '74LS245');
    });

    test('has the correct 20-pin layout', () {
      const expected = {
        1: ('DIR', 'input'),
        2: ('A1', 'input'),
        3: ('A2', 'input'),
        4: ('A3', 'input'),
        5: ('A4', 'input'),
        6: ('A5', 'input'),
        7: ('A6', 'input'),
        8: ('A7', 'input'),
        9: ('A8', 'input'),
        10: ('GND', 'ground'),
        11: ('B8', 'input'),
        12: ('B7', 'input'),
        13: ('B6', 'input'),
        14: ('B5', 'input'),
        15: ('B4', 'input'),
        16: ('B3', 'input'),
        17: ('B2', 'input'),
        18: ('B1', 'input'),
        19: ('~OE', 'input'),
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

    test('DIR high drives B from A', () {
      final inputs = <int, SignalState>{19: SignalState.low, 1: SignalState.high};
      for (var i = 0; i < 8; i++) {
        inputs[aPins[i]] = (i & 1) == 0 ? SignalState.low : SignalState.high;
      }
      final result = chip.evaluate(inputs);
      for (var i = 0; i < 8; i++) {
        expect(result[bPins[i]], inputs[aPins[i]], reason: 'B${i + 1}');
      }
    });

    test('DIR low drives A from B', () {
      final inputs = <int, SignalState>{19: SignalState.low, 1: SignalState.low};
      for (var i = 0; i < 8; i++) {
        inputs[bPins[i]] = (i & 1) == 0 ? SignalState.high : SignalState.low;
      }
      final result = chip.evaluate(inputs);
      for (var i = 0; i < 8; i++) {
        expect(result[aPins[i]], inputs[bPins[i]], reason: 'A${i + 1}');
      }
    });

    test('OE high puts both sides in high impedance', () {
      final result = chip.evaluate({
        19: SignalState.high,
        1: SignalState.high,
        2: SignalState.high,
      });
      for (final pin in [...aPins, ...bPins]) {
        expect(result[pin], SignalState.highZ, reason: 'pin $pin');
      }
    });

    test('unknown OE makes both sides unknown', () {
      final result = chip.evaluate({19: SignalState.unknown, 1: SignalState.high});
      for (final pin in [...aPins, ...bPins]) {
        expect(result[pin], SignalState.unknown, reason: 'pin $pin');
      }
    });

    test('unknown DIR makes both sides unknown', () {
      final result = chip.evaluate({19: SignalState.low, 1: SignalState.unknown});
      for (final pin in [...aPins, ...bPins]) {
        expect(result[pin], SignalState.unknown, reason: 'pin $pin');
      }
    });

    test('unknown source data passes unknown to the target side', () {
      final result = chip.evaluate({
        19: SignalState.low,
        1: SignalState.high, // A -> B
        2: SignalState.unknown, // A1
        3: SignalState.high, // A2
        18: SignalState.unknown, // B1 ignored as target input
        17: SignalState.low, // B2 ignored
      });
      expect(result[18], SignalState.unknown);
      expect(result[17], SignalState.high);
    });

    test('floating source data makes the target output unknown', () {
      final result = chip.evaluate({
        19: SignalState.low,
        1: SignalState.low, // B -> A
        18: SignalState.highZ, // B1 floating
        17: SignalState.high, // B2
      });
      expect(result[2], SignalState.unknown);
      expect(result[3], SignalState.high);
    });

    test('highZ on DIR or OE makes both sides unknown', () {
      for (final floatingPin in const [1, 19]) {
        final result = chip.evaluate({floatingPin: SignalState.highZ});
        for (final pin in [...aPins, ...bPins]) {
          expect(result[pin], SignalState.unknown,
              reason: 'pin $pin with floating pin $floatingPin');
        }
      }
    });
  });
}
