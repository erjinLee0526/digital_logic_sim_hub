import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls273.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS273 chip;

  setUp(() {
    chip = Chip74LS273();
  });

  group('Chip74LS273', () {
    test('has correct model and DIP-20 pinout', () {
      expect(chip.model, '74LS273');
      expect(chip.pinDefinitions.length, 20);

      const expected = {
        1: ('~MR', 'input'),
        2: ('1Q', 'output'),
        3: ('1D', 'input'),
        4: ('2D', 'input'),
        5: ('2Q', 'output'),
        6: ('3Q', 'output'),
        7: ('3D', 'input'),
        8: ('4D', 'input'),
        9: ('4Q', 'output'),
        10: ('GND', 'ground'),
        11: ('CP', 'input'),
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

    test('asynchronous clear resets all eight outputs', () {
      final result = chip.evaluate({
        1: SignalState.low,
        3: SignalState.high,
        4: SignalState.high,
        7: SignalState.high,
        8: SignalState.high,
        11: SignalState.high,
        13: SignalState.high,
        14: SignalState.high,
        17: SignalState.high,
        18: SignalState.high,
      });

      for (final q in [2, 5, 6, 9, 12, 15, 16, 19]) {
        expect(result[q], SignalState.low, reason: 'Q pin $q');
      }
    });

    test('rising edge latches all eight D inputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        1: SignalState.high,
        3: SignalState.high,
        4: SignalState.low,
        7: SignalState.high,
        8: SignalState.low,
        11: SignalState.low,
        13: SignalState.high,
        14: SignalState.low,
        17: SignalState.high,
        18: SignalState.low,
      };

      chip.evaluate(base, internalState: state);
      final result = chip.evaluate(
        {...base, 11: SignalState.high},
        internalState: state,
      );

      expect(result[2], SignalState.high);
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.high);
      expect(result[9], SignalState.low);
      expect(result[12], SignalState.high);
      expect(result[15], SignalState.low);
      expect(result[16], SignalState.high);
      expect(result[19], SignalState.low);
    });

    test('changing D while CP is high does not change outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.high;
      final result = chip.evaluate(
        {
          1: SignalState.high,
          3: SignalState.low,
          11: SignalState.high,
          2: SignalState.high,
        },
        internalState: state,
      );

      expect(result[2], SignalState.high);
    });

    test('unknown or highZ D at edge produces unknown output', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final unknownResult = chip.evaluate(
        {1: SignalState.high, 3: SignalState.unknown, 11: SignalState.high},
        internalState: state,
      );
      expect(unknownResult[2], SignalState.unknown);

      state['prev_clk'] = SignalState.low;
      final highZResult = chip.evaluate(
        {1: SignalState.high, 3: SignalState.highZ, 11: SignalState.high},
        internalState: state,
      );
      expect(highZResult[2], SignalState.unknown);
    });
  });
}
