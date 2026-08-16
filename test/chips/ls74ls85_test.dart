import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls85.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS85 chip;

  setUp(() => chip = Chip74LS85());

  SignalState bit(int value, int index) =>
      (value & (1 << index)) != 0 ? SignalState.high : SignalState.low;

  Map<int, SignalState> inputsFor(
    int a,
    int b, {
    SignalState iaGt = SignalState.low,
    SignalState iaEq = SignalState.high,
    SignalState iaLt = SignalState.low,
  }) {
    return {
      10: bit(a, 0), // A0
      12: bit(a, 1), // A1
      13: bit(a, 2), // A2
      15: bit(a, 3), // A3
      9: bit(b, 0), // B0
      11: bit(b, 1), // B1
      14: bit(b, 2), // B2
      1: bit(b, 3), // B3
      4: iaGt,
      3: iaEq,
      2: iaLt,
    };
  }

  group('Chip74LS85', () {
    test('has correct model number', () {
      expect(chip.model, '74LS85');
    });

    test('has the correct 16-pin layout', () {
      const expected = {
        1: ('B3', 'input'),
        2: ('IA<B', 'input'),
        3: ('IA=B', 'input'),
        4: ('IA>B', 'input'),
        5: ('OA>B', 'output'),
        6: ('OA=B', 'output'),
        7: ('OA<B', 'output'),
        8: ('GND', 'ground'),
        9: ('B0', 'input'),
        10: ('A0', 'input'),
        11: ('B1', 'input'),
        12: ('A1', 'input'),
        13: ('A2', 'input'),
        14: ('B2', 'input'),
        15: ('A3', 'input'),
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

    test('compares all 256 A/B combinations correctly', () {
      for (var a = 0; a < 16; a++) {
        for (var b = 0; b < 16; b++) {
          final result = chip.evaluate(inputsFor(a, b));
          expect(result[5], bit(a > b ? 1 : 0, 0),
              reason: 'OA>B for A=$a B=$b');
          expect(result[6], bit(a == b ? 1 : 0, 0),
              reason: 'OA=B for A=$a B=$b');
          expect(result[7], bit(a < b ? 1 : 0, 0),
              reason: 'OA<B for A=$a B=$b');
        }
      }
    });

    test('cascade inputs pass through when the words are equal', () {
      var result = chip.evaluate(
          inputsFor(5, 5, iaGt: SignalState.high, iaEq: SignalState.low));
      expect(result[5], SignalState.high);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);

      result = chip.evaluate(
          inputsFor(5, 5, iaGt: SignalState.low, iaEq: SignalState.high));
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.low);

      result = chip.evaluate(
          inputsFor(5, 5, iaGt: SignalState.low, iaEq: SignalState.low,
              iaLt: SignalState.high));
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.high);
    });

    test('the most significant differing bit decides the result', () {
      // A3=1 > B3=0 even though all lower bits favor B.
      final result = chip.evaluate(inputsFor(8, 7));
      expect(result[5], SignalState.high);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);
    });

    test('unknown data bit makes all outputs unknown', () {
      final result = chip.evaluate({
        10: SignalState.low,
        12: SignalState.unknown, // A1 unknown
        13: SignalState.low,
        15: SignalState.low,
        9: SignalState.low,
        11: SignalState.low,
        14: SignalState.low,
        1: SignalState.low,
      });
      expect(result[5], SignalState.unknown);
      expect(result[6], SignalState.unknown);
      expect(result[7], SignalState.unknown);
    });

    test('highZ data bit makes all outputs unknown', () {
      final result = chip.evaluate({
        10: SignalState.low,
        12: SignalState.low,
        13: SignalState.low,
        15: SignalState.highZ, // A3 floating
        9: SignalState.low,
        11: SignalState.low,
        14: SignalState.low,
        1: SignalState.low,
      });
      expect(result[5], SignalState.unknown);
      expect(result[6], SignalState.unknown);
      expect(result[7], SignalState.unknown);
    });

    test('unknown cascade input only matters when the words are equal', () {
      // Equal words: unknown IA=B makes OA=B unknown while others follow.
      var result = chip.evaluate(
          inputsFor(3, 3, iaEq: SignalState.unknown, iaLt: SignalState.high));
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.unknown);
      expect(result[7], SignalState.high);

      // Unequal words: cascade inputs are ignored entirely.
      result = chip.evaluate(
          inputsFor(4, 3, iaEq: SignalState.unknown, iaLt: SignalState.unknown));
      expect(result[5], SignalState.high);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);
    });

    test('highZ cascade input becomes unknown when the words are equal', () {
      final result = chip.evaluate(inputsFor(9, 9, iaGt: SignalState.highZ));
      expect(result[5], SignalState.unknown);
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.low);
    });
  });
}
