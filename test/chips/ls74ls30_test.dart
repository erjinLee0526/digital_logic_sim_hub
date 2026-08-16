import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls30.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS30 chip;

  setUp(() => chip = Chip74LS30());

  const inputPins = [1, 2, 3, 4, 5, 6, 11, 12];

  group('Chip74LS30', () {
    test('has correct model number', () {
      expect(chip.model, '74LS30');
    });

    test('has the correct modeled pin layout (pins 9/10/13 NC omitted)', () {
      const expected = {
        1: ('A', 'input'),
        2: ('B', 'input'),
        3: ('C', 'input'),
        4: ('D', 'input'),
        5: ('E', 'input'),
        6: ('F', 'input'),
        7: ('GND', 'ground'),
        8: ('Y', 'output'),
        11: ('G', 'input'),
        12: ('H', 'input'),
        14: ('VCC', 'power'),
      };
      expect(chip.pinDefinitions.length, 11);
      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key}');
        expect(pin.direction.name, entry.value.$2, reason: 'pin ${entry.key}');
      }
      for (final nc in const [9, 10, 13]) {
        expect(chip.pinDefinitions.any((p) => p.number == nc), isFalse,
            reason: 'pin $nc should be unmodeled');
      }
    });

    test('follows the NAND function for all 256 input combinations', () {
      for (var mask = 0; mask < 256; mask++) {
        final inputs = <int, SignalState>{
          for (var i = 0; i < 8; i++)
            inputPins[i]: (mask & (1 << i)) != 0
                ? SignalState.high
                : SignalState.low,
        };
        final result = chip.evaluate(inputs);
        final expected =
            mask == 255 ? SignalState.low : SignalState.high;
        expect(result[8], expected, reason: 'mask $mask');
      }
    });

    test('low input dominates unknown (gives high output)', () {
      final inputs = <int, SignalState>{
        for (final pin in inputPins) pin: SignalState.high,
      };
      inputs[inputPins[2]] = SignalState.low; // C low
      inputs[inputPins[5]] = SignalState.unknown; // F unknown
      expect(chip.evaluate(inputs)[8], SignalState.high);
    });

    test('non-dominated unknown input gives unknown output', () {
      final inputs = <int, SignalState>{
        for (final pin in inputPins) pin: SignalState.high,
      };
      inputs[inputPins[5]] = SignalState.unknown; // F unknown, rest high
      expect(chip.evaluate(inputs)[8], SignalState.unknown);
    });

    test('highZ input gives unknown even with a low input', () {
      final inputs = <int, SignalState>{
        for (final pin in inputPins) pin: SignalState.high,
      };
      inputs[inputPins[0]] = SignalState.low; // A low
      inputs[inputPins[7]] = SignalState.highZ; // H floating
      expect(chip.evaluate(inputs)[8], SignalState.unknown);
    });
  });
}
