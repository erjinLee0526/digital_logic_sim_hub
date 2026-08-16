import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls153.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS153 chip;

  setUp(() => chip = Chip74LS153());

  group('Chip74LS153', () {
    test('has correct model number', () {
      expect(chip.model, '74LS153');
    });

    test('has the correct 16-pin layout', () {
      const expected = {
        1: ('~1G', 'input'),
        2: ('B', 'input'),
        3: ('1C3', 'input'),
        4: ('1C2', 'input'),
        5: ('1C1', 'input'),
        6: ('1C0', 'input'),
        7: ('1Y', 'output'),
        8: ('GND', 'ground'),
        9: ('2Y', 'output'),
        10: ('2C0', 'input'),
        11: ('2C1', 'input'),
        12: ('2C2', 'input'),
        13: ('2C3', 'input'),
        14: ('A', 'input'),
        15: ('~2G', 'input'),
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

    test('mux 1 selects the C input addressed by B A', () {
      const dataPins = [6, 5, 4, 3]; // 1C0..1C3
      for (var sel = 0; sel < 4; sel++) {
        final inputs = <int, SignalState>{
          1: SignalState.low, // ~1G enabled
          14: (sel & 1) != 0 ? SignalState.high : SignalState.low, // A
          2: (sel & 2) != 0 ? SignalState.high : SignalState.low, // B
        };
        for (var i = 0; i < dataPins.length; i++) {
          inputs[dataPins[i]] = i == sel ? SignalState.high : SignalState.low;
        }
        final result = chip.evaluate(inputs);
        expect(result[7], SignalState.high, reason: 'sel $sel -> 1Y');
      }
    });

    test('mux 2 selects the C input addressed by B A', () {
      const dataPins = [10, 11, 12, 13]; // 2C0..2C3
      for (var sel = 0; sel < 4; sel++) {
        final inputs = <int, SignalState>{
          15: SignalState.low, // ~2G enabled
          14: (sel & 1) != 0 ? SignalState.high : SignalState.low, // A
          2: (sel & 2) != 0 ? SignalState.high : SignalState.low, // B
        };
        for (var i = 0; i < dataPins.length; i++) {
          inputs[dataPins[i]] = i == sel ? SignalState.high : SignalState.low;
        }
        final result = chip.evaluate(inputs);
        expect(result[9], SignalState.high, reason: 'sel $sel -> 2Y');
      }
    });

    test('the shared address selects the same index in both muxes', () {
      final result = chip.evaluate({
        1: SignalState.low, // ~1G enabled
        15: SignalState.low, // ~2G enabled
        14: SignalState.high, // A
        2: SignalState.high, // B -> sel = 3
        6: SignalState.low, // 1C0
        5: SignalState.low, // 1C1
        4: SignalState.low, // 1C2
        3: SignalState.high, // 1C3 selected
        10: SignalState.low, // 2C0
        11: SignalState.high, // 2C1
        12: SignalState.low, // 2C2
        13: SignalState.low, // 2C3
      });
      expect(result[7], SignalState.high); // 1C3 = high
      expect(result[9], SignalState.low); // 2C3 = low
    });

    test('disabled mux output is low regardless of address and data', () {
      final result = chip.evaluate({
        1: SignalState.high, // ~1G disabled
        14: SignalState.unknown,
        2: SignalState.unknown,
        6: SignalState.unknown,
        5: SignalState.unknown,
        4: SignalState.unknown,
        3: SignalState.unknown,
        15: SignalState.low, // ~2G enabled
        10: SignalState.high, // 2C0 selected when A=B=... unknown -> unknown
      });
      expect(result[7], SignalState.low);
    });

    test('unknown enable makes only that mux unknown', () {
      final result = chip.evaluate({
        1: SignalState.unknown, // ~1G
        14: SignalState.low,
        2: SignalState.low,
        6: SignalState.high, // 1C0
        15: SignalState.low, // ~2G enabled
        10: SignalState.high, // 2C0 -> selected, 2Y high
      });
      expect(result[7], SignalState.unknown);
      expect(result[9], SignalState.high);
    });

    test('unknown address makes both enabled muxes unknown', () {
      final result = chip.evaluate({
        1: SignalState.low,
        15: SignalState.low,
        14: SignalState.unknown, // A
        2: SignalState.low, // B
        6: SignalState.high,
        10: SignalState.high,
      });
      expect(result[7], SignalState.unknown);
      expect(result[9], SignalState.unknown);
    });

    test('unknown selected data makes that output unknown', () {
      final result = chip.evaluate({
        1: SignalState.low,
        14: SignalState.low, // A
        2: SignalState.high, // B -> sel = 2 (1C2)
        6: SignalState.low, // 1C0
        5: SignalState.low, // 1C1
        4: SignalState.unknown, // 1C2 selected
        3: SignalState.low, // 1C3
      });
      expect(result[7], SignalState.unknown);
    });

    test('unknown unselected data does not affect the output', () {
      final result = chip.evaluate({
        1: SignalState.low,
        14: SignalState.low, // A
        2: SignalState.low, // B -> sel = 0 (1C0)
        6: SignalState.high, // 1C0 selected
        5: SignalState.unknown, // 1C1
        4: SignalState.unknown, // 1C2
        3: SignalState.unknown, // 1C3
      });
      expect(result[7], SignalState.high);
    });

    test('highZ on any input of a mux makes that output unknown', () {
      final result = chip.evaluate({
        1: SignalState.low,
        14: SignalState.low,
        2: SignalState.low,
        6: SignalState.highZ, // 1C0 floating
        15: SignalState.low, // ~2G enabled
        10: SignalState.high, // 2C0 selected
      });
      expect(result[7], SignalState.unknown);
      expect(result[9], SignalState.high);
    });
  });
}
