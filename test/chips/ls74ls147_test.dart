import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls147.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS147 chip;

  setUp(() => chip = Chip74LS147());

  // I1..I9 pin numbers.
  const inputPins = [11, 12, 13, 1, 2, 3, 4, 5, 10];

  Map<int, SignalState> allInactive() => {
        for (final pin in inputPins) pin: SignalState.high,
      };

  SignalState bit(int value, int index) =>
      (value & (1 << index)) != 0 ? SignalState.high : SignalState.low;

  group('Chip74LS147', () {
    test('has correct model number', () {
      expect(chip.model, '74LS147');
    });

    test('has the correct modeled pin layout (pin 15 NC omitted)', () {
      const expected = {
        1: ('I4', 'input'),
        2: ('I5', 'input'),
        3: ('I6', 'input'),
        4: ('I7', 'input'),
        5: ('I8', 'input'),
        6: ('C', 'output'),
        7: ('B', 'output'),
        8: ('GND', 'ground'),
        9: ('A', 'output'),
        10: ('I9', 'input'),
        11: ('I1', 'input'),
        12: ('I2', 'input'),
        13: ('I3', 'input'),
        14: ('D', 'output'),
        16: ('VCC', 'power'),
      };
      expect(chip.pinDefinitions.length, 15);
      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key}');
        expect(pin.direction.name, entry.value.$2, reason: 'pin ${entry.key}');
      }
      expect(chip.pinDefinitions.any((p) => p.number == 15), isFalse);
    });

    test('encodes each active input as inverted BCD', () {
      for (var n = 1; n <= 9; n++) {
        final inputs = allInactive();
        inputs[inputPins[n - 1]] = SignalState.low; // I(n) active
        final result = chip.evaluate(inputs);
        final code = 15 - n;
        expect(result[9], bit(code, 0), reason: 'A for I$n');
        expect(result[7], bit(code, 1), reason: 'B for I$n');
        expect(result[6], bit(code, 2), reason: 'C for I$n');
        expect(result[14], bit(code, 3), reason: 'D for I$n');
      }
    });

    test('the highest-numbered active input wins', () {
      final inputs = allInactive();
      inputs[inputPins[0]] = SignalState.low; // I1
      inputs[inputPins[2]] = SignalState.low; // I3
      inputs[inputPins[6]] = SignalState.low; // I7 -> wins
      final result = chip.evaluate(inputs);
      const code = 15 - 7; // 0110
      expect(result[9], bit(code, 0));
      expect(result[7], bit(code, 1));
      expect(result[6], bit(code, 2));
      expect(result[14], bit(code, 3));
    });

    test('no active input produces 1111 (the code for 0)', () {
      final result = chip.evaluate(allInactive());
      expect(result[9], SignalState.high);
      expect(result[7], SignalState.high);
      expect(result[6], SignalState.high);
      expect(result[14], SignalState.high);
    });

    test('unknown input above the active one makes outputs unknown', () {
      final inputs = allInactive();
      inputs[inputPins[5]] = SignalState.low; // I6 active
      inputs[inputPins[7]] = SignalState.unknown; // I8 unknown (higher)
      final result = chip.evaluate(inputs);
      expect(result.values.every((v) => v == SignalState.unknown), isTrue);
    });

    test('unknown input below the active one is ignored', () {
      final inputs = allInactive();
      inputs[inputPins[8]] = SignalState.low; // I9 active
      inputs[inputPins[0]] = SignalState.unknown; // I1 (lower, irrelevant)
      final result = chip.evaluate(inputs);
      const code = 15 - 9; // 0110
      expect(result[9], bit(code, 0));
      expect(result[7], bit(code, 1));
      expect(result[6], bit(code, 2));
      expect(result[14], bit(code, 3));
    });

    test('highZ on any input makes outputs unknown', () {
      final inputs = allInactive();
      inputs[inputPins[4]] = SignalState.highZ; // I5 floating
      final result = chip.evaluate(inputs);
      expect(result.values.every((v) => v == SignalState.unknown), isTrue);
    });
  });
}
