import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls175.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS175 chip;

  setUp(() {
    chip = Chip74LS175();
  });

  group('Chip74LS175', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS175');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('~MR', 'input'),
        2: ('1Q', 'output'),
        3: ('~1Q', 'output'),
        4: ('1D', 'input'),
        5: ('2D', 'input'),
        6: ('~2Q', 'output'),
        7: ('2Q', 'output'),
        8: ('GND', 'ground'),
        9: ('CP', 'input'),
        10: ('~3Q', 'output'),
        11: ('3Q', 'output'),
        12: ('3D', 'input'),
        13: ('4D', 'input'),
        14: ('~4Q', 'output'),
        15: ('4Q', 'output'),
        16: ('VCC', 'power'),
      };

      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key} label');
        expect(pin.direction.name, entry.value.$2,
            reason: 'pin ${entry.key} direction');
      }
    });

    test('asynchronous clear has priority over clock', () {
      final result = chip.evaluate({
        1: SignalState.low,
        4: SignalState.high,
        5: SignalState.high,
        9: SignalState.high,
        12: SignalState.high,
        13: SignalState.high,
      });

      expect(result[2], SignalState.low);
      expect(result[3], SignalState.high);
      expect(result[7], SignalState.low);
      expect(result[11], SignalState.low);
      expect(result[15], SignalState.low);
    });

    test('rising edge latches all D inputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        1: SignalState.high,
        4: SignalState.high,
        5: SignalState.low,
        9: SignalState.low,
        12: SignalState.high,
        13: SignalState.low,
      };

      chip.evaluate(base, internalState: state);
      final result = chip.evaluate(
        {...base, 9: SignalState.high},
        internalState: state,
      );

      expect(result[2], SignalState.high);
      expect(result[3], SignalState.low);
      expect(result[7], SignalState.low);
      expect(result[6], SignalState.high);
      expect(result[11], SignalState.high);
      expect(result[15], SignalState.low);
      expect(result[14], SignalState.high);
    });

    test('changing D while CP is high does not change outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.high;
      final result = chip.evaluate(
        {
          1: SignalState.high,
          4: SignalState.low,
          9: SignalState.high,
          2: SignalState.high,
          3: SignalState.low,
        },
        internalState: state,
      );

      expect(result[2], SignalState.high);
      expect(result[3], SignalState.low);
    });

    test('unknown or highZ D at edge produces unknown outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final unknownResult = chip.evaluate(
        {1: SignalState.high, 4: SignalState.unknown, 9: SignalState.high},
        internalState: state,
      );
      expect(unknownResult[2], SignalState.unknown);
      expect(unknownResult[3], SignalState.unknown);

      state['prev_clk'] = SignalState.low;
      final highZResult = chip.evaluate(
        {1: SignalState.high, 4: SignalState.highZ, 9: SignalState.high},
        internalState: state,
      );
      expect(highZResult[2], SignalState.unknown);
      expect(highZResult[3], SignalState.unknown);
    });
  });
}
