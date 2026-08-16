import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls151.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS151 chip;

  setUp(() => chip = Chip74LS151());

  group('Chip74LS151', () {
    test('has correct model number', () {
      expect(chip.model, '74LS151');
    });

    test('has the correct 16-pin layout', () {
      const expected = {
        1: ('D3', 'input'),
        2: ('D2', 'input'),
        3: ('D1', 'input'),
        4: ('D0', 'input'),
        5: ('Y', 'output'),
        6: ('~W', 'output'),
        7: ('~S', 'input'),
        8: ('GND', 'ground'),
        9: ('C', 'input'),
        10: ('B', 'input'),
        11: ('A', 'input'),
        12: ('D7', 'input'),
        13: ('D6', 'input'),
        14: ('D5', 'input'),
        15: ('D4', 'input'),
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

    test('selects the data input addressed by CBA', () {
      // D0..D7 pin numbers in select-code order (A=LSB, C=MSB)
      const dataPins = [4, 3, 2, 1, 15, 14, 13, 12];
      for (var sel = 0; sel < 8; sel++) {
        final inputs = <int, SignalState>{
          7: SignalState.low, // ~S enabled
          11: (sel & 1) != 0 ? SignalState.high : SignalState.low, // A
          10: (sel & 2) != 0 ? SignalState.high : SignalState.low, // B
          9: (sel & 4) != 0 ? SignalState.high : SignalState.low, // C
        };
        for (var i = 0; i < dataPins.length; i++) {
          inputs[dataPins[i]] =
              i == sel ? SignalState.high : SignalState.low;
        }
        final result = chip.evaluate(inputs);
        expect(result[5], SignalState.high, reason: 'sel $sel -> Y');
        expect(result[6], SignalState.low, reason: 'sel $sel -> ~W');
      }
    });

    test('~W is the complement of Y', () {
      // Select D2 (pin 2) with a low level.
      final result = chip.evaluate({
        7: SignalState.low,
        11: SignalState.low, // A
        10: SignalState.high, // B -> sel = 2
        9: SignalState.low, // C
        4: SignalState.high, // D0
        3: SignalState.high, // D1
        2: SignalState.low, // D2 (selected)
        1: SignalState.high, // D3
        15: SignalState.high, // D4
        14: SignalState.high, // D5
        13: SignalState.high, // D6
        12: SignalState.high, // D7
      });
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.high);
    });

    test('strobe high forces Y=0 and ~W=1 regardless of inputs', () {
      final result = chip.evaluate({
        7: SignalState.high, // ~S disabled
        11: SignalState.unknown,
        10: SignalState.high,
        9: SignalState.low,
        4: SignalState.high,
        3: SignalState.high,
        2: SignalState.high,
        1: SignalState.high,
        15: SignalState.high,
        14: SignalState.high,
        13: SignalState.high,
        12: SignalState.high,
      });
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.high);
    });

    test('unknown strobe makes both outputs unknown', () {
      final result = chip.evaluate({
        7: SignalState.unknown,
        11: SignalState.low,
        10: SignalState.low,
        9: SignalState.low,
      });
      expect(result[5], SignalState.unknown);
      expect(result[6], SignalState.unknown);
    });

    test('unknown address makes both outputs unknown', () {
      final result = chip.evaluate({
        7: SignalState.low,
        11: SignalState.unknown, // A
        10: SignalState.low,
        9: SignalState.low,
        4: SignalState.high,
      });
      expect(result[5], SignalState.unknown);
      expect(result[6], SignalState.unknown);
    });

    test('unknown selected data makes both outputs unknown', () {
      final result = chip.evaluate({
        7: SignalState.low,
        11: SignalState.high, // A
        10: SignalState.low, // B -> sel = 1 (D1)
        9: SignalState.low,
        4: SignalState.low, // D0
        3: SignalState.unknown, // D1 (selected)
      });
      expect(result[5], SignalState.unknown);
      expect(result[6], SignalState.unknown);
    });

    test('unknown unselected data does not affect the output', () {
      final result = chip.evaluate({
        7: SignalState.low,
        11: SignalState.low, // A
        10: SignalState.low, // B
        9: SignalState.low, // C -> sel = 0 (D0)
        4: SignalState.high, // D0 (selected)
        3: SignalState.unknown, // D1 (not selected)
        2: SignalState.unknown, // D2 (not selected)
        1: SignalState.unknown, // D3 (not selected)
        15: SignalState.unknown, // D4 (not selected)
        14: SignalState.unknown, // D5 (not selected)
        13: SignalState.unknown, // D6 (not selected)
        12: SignalState.unknown, // D7 (not selected)
      });
      expect(result[5], SignalState.high);
      expect(result[6], SignalState.low);
    });

    test('highZ on any input makes both outputs unknown', () {
      final result = chip.evaluate({
        7: SignalState.low,
        11: SignalState.low,
        10: SignalState.low,
        9: SignalState.low,
        4: SignalState.highZ, // D0 floating
      });
      expect(result[5], SignalState.unknown);
      expect(result[6], SignalState.unknown);
    });
  });
}
