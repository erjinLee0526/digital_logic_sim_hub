import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls174.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS174 chip;

  setUp(() {
    chip = Chip74LS174();
  });

  group('Chip74LS174', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS174');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('~MR', 'input'),
        2: ('Q0', 'output'),
        3: ('D0', 'input'),
        4: ('D1', 'input'),
        5: ('Q1', 'output'),
        6: ('D2', 'input'),
        7: ('Q2', 'output'),
        8: ('GND', 'ground'),
        9: ('CP', 'input'),
        10: ('Q3', 'output'),
        11: ('D3', 'input'),
        12: ('Q4', 'output'),
        13: ('D4', 'input'),
        14: ('D5', 'input'),
        15: ('Q5', 'output'),
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
        3: SignalState.high,
        4: SignalState.high,
        6: SignalState.high,
        9: SignalState.high,
        11: SignalState.high,
        13: SignalState.high,
        14: SignalState.high,
      });

      for (final qPin in [2, 5, 7, 10, 12, 15]) {
        expect(result[qPin], SignalState.low, reason: 'Q pin $qPin');
      }
    });

    test('rising edge latches all six D inputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        1: SignalState.high,
        3: SignalState.high, // D0
        4: SignalState.low, // D1
        6: SignalState.high, // D2
        9: SignalState.low, // CP
        11: SignalState.low, // D3
        13: SignalState.high, // D4
        14: SignalState.low, // D5
      };

      chip.evaluate(base, internalState: state);
      final result = chip.evaluate(
        {...base, 9: SignalState.high},
        internalState: state,
      );

      expect(result[2], SignalState.high);
      expect(result[5], SignalState.low);
      expect(result[7], SignalState.high);
      expect(result[10], SignalState.low);
      expect(result[12], SignalState.high);
      expect(result[15], SignalState.low);
    });

    test('changing D while CP is high does not change outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.high;
      final result = chip.evaluate(
        {
          1: SignalState.high,
          3: SignalState.low,
          9: SignalState.high,
          2: SignalState.high,
        },
        internalState: state,
      );

      expect(result[2], SignalState.high);
    });

    test('unknown or highZ D at edge produces unknown output', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final unknownResult = chip.evaluate(
        {1: SignalState.high, 3: SignalState.unknown, 9: SignalState.high},
        internalState: state,
      );
      expect(unknownResult[2], SignalState.unknown);

      state['prev_clk'] = SignalState.low;
      final highZResult = chip.evaluate(
        {1: SignalState.high, 3: SignalState.highZ, 9: SignalState.high},
        internalState: state,
      );
      expect(highZResult[2], SignalState.unknown);
    });
  });
}
