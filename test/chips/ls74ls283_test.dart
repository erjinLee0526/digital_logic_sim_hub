import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls283.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS283 chip;

  setUp(() => chip = Chip74LS283());

  group('Chip74LS283', () {
    test('has correct model number', () {
      expect(chip.model, '74LS283');
    });

    test('has the correct 16-pin layout', () {
      const expected = {
        1: ('S1', 'output'),
        2: ('B1', 'input'),
        3: ('A1', 'input'),
        4: ('S0', 'output'),
        5: ('A0', 'input'),
        6: ('B0', 'input'),
        7: ('C0', 'input'),
        8: ('GND', 'ground'),
        9: ('C4', 'output'),
        10: ('S2', 'output'),
        11: ('B2', 'input'),
        12: ('A2', 'input'),
        13: ('S3', 'output'),
        14: ('A3', 'input'),
        15: ('B3', 'input'),
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

    test('computes A + B + C0 for all 512 input combinations', () {
      SignalState bit(int value, int index) =>
          (value & (1 << index)) != 0 ? SignalState.high : SignalState.low;
      const aPins = [5, 3, 12, 14]; // A0..A3
      const bPins = [6, 2, 11, 15]; // B0..B3
      const sumPins = [4, 1, 10, 13]; // S0..S3

      for (var a = 0; a < 16; a++) {
        for (var b = 0; b < 16; b++) {
          for (var ci = 0; ci < 2; ci++) {
            final inputs = <int, SignalState>{7: bit(ci, 0)};
            for (var i = 0; i < 4; i++) {
              inputs[aPins[i]] = bit(a, i);
              inputs[bPins[i]] = bit(b, i);
            }
            final result = chip.evaluate(inputs);
            final total = a + b + ci;
            for (var i = 0; i < 4; i++) {
              expect(result[sumPins[i]], bit(total, i),
                  reason: 'S$i for $a+$b+$ci');
            }
            expect(result[9], bit(total, 4), reason: 'C4 for $a+$b+$ci');
          }
        }
      }
    });

    test('carry ripples correctly in representative cases', () {
      SignalState bit(int value, int index) =>
          (value & (1 << index)) != 0 ? SignalState.high : SignalState.low;
      Map<int, SignalState> inputsFor(int a, int b, int ci) => {
            5: bit(a, 0),
            3: bit(a, 1),
            12: bit(a, 2),
            14: bit(a, 3),
            6: bit(b, 0),
            2: bit(b, 1),
            11: bit(b, 2),
            15: bit(b, 3),
            7: bit(ci, 0),
          };

      // 15 + 15 + 1 = 31 -> S = 1111, C4 = 1
      var result = chip.evaluate(inputsFor(15, 15, 1));
      expect(result[4], SignalState.high);
      expect(result[1], SignalState.high);
      expect(result[10], SignalState.high);
      expect(result[13], SignalState.high);
      expect(result[9], SignalState.high);

      // 7 + 8 + 0 = 15 -> S = 1111, C4 = 0
      result = chip.evaluate(inputsFor(7, 8, 0));
      expect(result[4], SignalState.high);
      expect(result[1], SignalState.high);
      expect(result[10], SignalState.high);
      expect(result[13], SignalState.high);
      expect(result[9], SignalState.low);

      // 0 + 0 + 1 = 1
      result = chip.evaluate(inputsFor(0, 0, 1));
      expect(result[4], SignalState.high);
      expect(result[1], SignalState.low);
      expect(result[10], SignalState.low);
      expect(result[13], SignalState.low);
      expect(result[9], SignalState.low);
    });

    test('unknown on any input makes all five outputs unknown', () {
      const drivenInputs = {
        5: SignalState.low,
        3: SignalState.low,
        12: SignalState.low,
        14: SignalState.low,
        6: SignalState.low,
        2: SignalState.low,
        11: SignalState.low,
        15: SignalState.low,
        7: SignalState.low,
      };
      for (final pin in const [5, 3, 12, 14, 6, 2, 11, 15, 7]) {
        final result = chip.evaluate({...drivenInputs, pin: SignalState.unknown});
        expect(result.values.every((v) => v == SignalState.unknown), isTrue,
            reason: 'unknown on pin $pin');
      }
    });

    test('highZ on any input makes all five outputs unknown', () {
      final result = chip.evaluate({
        5: SignalState.low,
        3: SignalState.low,
        12: SignalState.low,
        14: SignalState.low,
        6: SignalState.low,
        2: SignalState.low,
        11: SignalState.highZ, // B2 floating
        15: SignalState.low,
        7: SignalState.low,
      });
      expect(result.values.every((v) => v == SignalState.unknown), isTrue);
    });
  });
}
