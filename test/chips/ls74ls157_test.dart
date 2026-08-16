import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls157.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS157 chip;

  setUp(() => chip = Chip74LS157());

  group('Chip74LS157', () {
    test('has correct model number', () {
      expect(chip.model, '74LS157');
    });

    test('has the correct 16-pin layout', () {
      const expected = {
        1: ('S', 'input'),
        2: ('1A', 'input'),
        3: ('1B', 'input'),
        4: ('1Y', 'output'),
        5: ('2A', 'input'),
        6: ('2B', 'input'),
        7: ('2Y', 'output'),
        8: ('GND', 'ground'),
        9: ('3Y', 'output'),
        10: ('3B', 'input'),
        11: ('3A', 'input'),
        12: ('4Y', 'output'),
        13: ('4B', 'input'),
        14: ('4A', 'input'),
        15: ('~E', 'input'),
        16: ('VCC', 'power'),
      };
      expect(chip.pinDefinitions.length, 16);
      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key}');
        expect(pin.direction.name, entry.value.$2, reason: 'pin ${entry.key}');
      }
    });

    test('S low selects A and S high selects B for all four muxes', () {
      const pairs = [
        (a: 2, b: 3, y: 4),
        (a: 5, b: 6, y: 7),
        (a: 11, b: 10, y: 9),
        (a: 14, b: 13, y: 12),
      ];
      for (final select in [SignalState.low, SignalState.high]) {
        final inputs = <int, SignalState>{15: SignalState.low, 1: select};
        for (final pair in pairs) {
          inputs[pair.a] = SignalState.low;
          inputs[pair.b] = SignalState.high;
        }
        final result = chip.evaluate(inputs);
        for (final pair in pairs) {
          expect(
            result[pair.y],
            select == SignalState.low ? SignalState.low : SignalState.high,
            reason: 'S=$select, Y${pairs.indexOf(pair) + 1}',
          );
        }
      }
    });

    test('enable high forces every output low', () {
      final result = chip.evaluate({
        15: SignalState.high, // ~E disabled
        1: SignalState.unknown,
        2: SignalState.high,
        3: SignalState.high,
        5: SignalState.high,
        6: SignalState.high,
        11: SignalState.high,
        10: SignalState.high,
        14: SignalState.high,
        13: SignalState.high,
      });
      for (final pin in const [4, 7, 9, 12]) {
        expect(result[pin], SignalState.low, reason: 'pin $pin');
      }
    });

    test('unknown enable makes every output unknown', () {
      final result = chip.evaluate({15: SignalState.unknown, 1: SignalState.low});
      for (final pin in const [4, 7, 9, 12]) {
        expect(result[pin], SignalState.unknown, reason: 'pin $pin');
      }
    });

    test('unknown select makes every output unknown', () {
      final result = chip.evaluate({15: SignalState.low, 1: SignalState.unknown});
      for (final pin in const [4, 7, 9, 12]) {
        expect(result[pin], SignalState.unknown, reason: 'pin $pin');
      }
    });

    test('unknown selected data makes only that output unknown', () {
      final result = chip.evaluate({
        15: SignalState.low,
        1: SignalState.low, // select A inputs
        2: SignalState.unknown, // 1A selected
        3: SignalState.high, // 1B
        5: SignalState.low, // 2A selected
        6: SignalState.high, // 2B
        11: SignalState.low, // 3A selected
        10: SignalState.high, // 3B
        14: SignalState.low, // 4A selected
        13: SignalState.high, // 4B
      });
      expect(result[4], SignalState.unknown);
      expect(result[7], SignalState.low);
      expect(result[9], SignalState.low);
      expect(result[12], SignalState.low);
    });

    test('unknown unselected data does not affect the output', () {
      final result = chip.evaluate({
        15: SignalState.low,
        1: SignalState.low, // select A inputs
        2: SignalState.high, // 1A selected
        3: SignalState.unknown, // 1B unselected
        5: SignalState.high, // 2A selected
        6: SignalState.unknown, // 2B unselected
        11: SignalState.high, // 3A selected
        10: SignalState.unknown, // 3B unselected
        14: SignalState.high, // 4A selected
        13: SignalState.unknown, // 4B unselected
      });
      for (final pin in const [4, 7, 9, 12]) {
        expect(result[pin], SignalState.high, reason: 'pin $pin');
      }
    });

    test('highZ on one mux only makes that mux unknown', () {
      final result = chip.evaluate({
        15: SignalState.low,
        1: SignalState.low,
        2: SignalState.highZ, // 1A floating
        5: SignalState.high,
        11: SignalState.high,
        14: SignalState.high,
      });
      expect(result[4], SignalState.unknown);
      expect(result[7], SignalState.high);
      expect(result[9], SignalState.high);
      expect(result[12], SignalState.high);
    });

    test('highZ on shared S makes every output unknown', () {
      final result = chip.evaluate({
        15: SignalState.low,
        1: SignalState.highZ,
        2: SignalState.high,
        5: SignalState.high,
        11: SignalState.high,
        14: SignalState.high,
      });
      for (final pin in const [4, 7, 9, 12]) {
        expect(result[pin], SignalState.unknown, reason: 'pin $pin');
      }
    });
  });
}
