import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls373.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS373 chip;

  setUp(() {
    chip = Chip74LS373();
  });

  group('Chip74LS373', () {
    test('has correct model and DIP-20 pinout', () {
      expect(chip.model, '74LS373');
      expect(chip.pinDefinitions.length, 20);

      const expected = {
        1: ('~OE', 'input'),
        2: ('1Q', 'output'),
        3: ('1D', 'input'),
        4: ('2D', 'input'),
        5: ('2Q', 'output'),
        6: ('3Q', 'output'),
        7: ('3D', 'input'),
        8: ('4D', 'input'),
        9: ('4Q', 'output'),
        10: ('GND', 'ground'),
        11: ('LE', 'input'),
        12: ('5Q', 'output'),
        13: ('5D', 'input'),
        14: ('6D', 'input'),
        15: ('6Q', 'output'),
        16: ('7Q', 'output'),
        17: ('7D', 'input'),
        18: ('8D', 'input'),
        19: ('8Q', 'output'),
        20: ('VCC', 'power'),
      };

      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key} label');
        expect(pin.direction.name, entry.value.$2,
            reason: 'pin ${entry.key} direction');
      }
    });

    test('LE high and OE low makes the latch transparent', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          1: SignalState.low,
          3: SignalState.high,
          11: SignalState.high,
        },
        internalState: state,
      );

      expect(result[2], SignalState.high);
    });

    test('falling LE latches the data', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      chip.evaluate(
        {1: SignalState.low, 3: SignalState.high, 11: SignalState.high},
        internalState: state,
      );

      final result = chip.evaluate(
        {1: SignalState.low, 3: SignalState.low, 11: SignalState.low},
        internalState: state,
      );
      expect(result[2], SignalState.high);
    });

    test('OE high puts outputs in high impedance', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      chip.evaluate(
        {1: SignalState.low, 3: SignalState.high, 11: SignalState.high},
        internalState: state,
      );

      final disabled = chip.evaluate(
        {1: SignalState.high, 3: SignalState.high, 11: SignalState.high},
        internalState: state,
      );
      expect(disabled[2], SignalState.highZ);

      final enabledAgain = chip.evaluate(
        {1: SignalState.low, 3: SignalState.low, 11: SignalState.low},
        internalState: state,
      );
      expect(enabledAgain[2], SignalState.high);
    });

    test('unknown or highZ D while LE is high gives unknown latch value', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final unknownResult = chip.evaluate(
        {1: SignalState.low, 3: SignalState.unknown, 11: SignalState.high},
        internalState: state,
      );
      expect(unknownResult[2], SignalState.unknown);

      final highZResult = chip.evaluate(
        {1: SignalState.low, 3: SignalState.highZ, 11: SignalState.high},
        internalState: state,
      );
      expect(highZResult[2], SignalState.unknown);
    });
  });
}
