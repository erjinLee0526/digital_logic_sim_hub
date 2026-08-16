import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls112.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS112 chip;

  setUp(() {
    chip = Chip74LS112();
  });

  group('Chip74LS112', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS112');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('1CLK', 'input'),
        2: ('1K', 'input'),
        3: ('1J', 'input'),
        4: ('~1PRE', 'input'),
        5: ('1Q', 'output'),
        6: ('~1Q', 'output'),
        7: ('~2Q', 'output'),
        8: ('GND', 'ground'),
        9: ('2Q', 'output'),
        10: ('~2PRE', 'input'),
        11: ('2J', 'input'),
        12: ('2K', 'input'),
        13: ('2CLK', 'input'),
        14: ('~2CLR', 'input'),
        15: ('~1CLR', 'input'),
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

    test('falling edge performs set, reset, toggle and hold', () {
      final state = Map<String, SignalState>.of(chip.initialState);

      // Async clear establishes a known low state.
      var inputs = <int, SignalState>{
        1: SignalState.high, // 1CLK
        2: SignalState.low, // 1K
        3: SignalState.low, // 1J
        4: SignalState.high, // ~1PRE inactive
        15: SignalState.low, // ~1CLR active
        5: SignalState.unknown, // 1Q
        6: SignalState.unknown, // ~1Q
      };
      var result = chip.evaluate(inputs, internalState: state);
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.high);

      // J=1, K=0: set on the falling edge.
      inputs = {
        1: SignalState.high,
        2: SignalState.low,
        3: SignalState.high,
        4: SignalState.high,
        15: SignalState.high,
        5: SignalState.low,
        6: SignalState.high,
      };
      chip.evaluate(inputs, internalState: state);
      result = chip.evaluate(
        {...inputs, 1: SignalState.low},
        internalState: state,
      );
      expect(result[5], SignalState.high);
      expect(result[6], SignalState.low);

      // J=0, K=1: reset on the falling edge.
      inputs = {
        1: SignalState.high,
        2: SignalState.high,
        3: SignalState.low,
        4: SignalState.high,
        15: SignalState.high,
        5: SignalState.high,
        6: SignalState.low,
      };
      chip.evaluate(inputs, internalState: state);
      result = chip.evaluate(
        {...inputs, 1: SignalState.low},
        internalState: state,
      );
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.high);

      // J=K=1: toggle on each falling edge.
      inputs = {
        1: SignalState.high,
        2: SignalState.high,
        3: SignalState.high,
        4: SignalState.high,
        15: SignalState.high,
        5: SignalState.low,
        6: SignalState.high,
      };
      chip.evaluate(inputs, internalState: state);
      result = chip.evaluate(
        {...inputs, 1: SignalState.low},
        internalState: state,
      );
      expect(result[5], SignalState.high);
      expect(result[6], SignalState.low);
      inputs = {
        ...inputs,
        1: SignalState.high,
        5: result[5]!,
        6: result[6]!,
      };
      chip.evaluate(inputs, internalState: state);
      result = chip.evaluate(
        {...inputs, 1: SignalState.low},
        internalState: state,
      );
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.high);

      // J=K=0: hold on the falling edge.
      inputs = {
        1: SignalState.high,
        2: SignalState.low,
        3: SignalState.low,
        4: SignalState.high,
        15: SignalState.high,
        5: SignalState.low,
        6: SignalState.high,
      };
      chip.evaluate(inputs, internalState: state);
      result = chip.evaluate(
        {...inputs, 1: SignalState.low},
        internalState: state,
      );
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.high);
    });

    test('asynchronous preset and clear override the clock', () {
      final state = Map<String, SignalState>.of(chip.initialState);

      final presetResult = chip.evaluate(
        {
          1: SignalState.low,
          2: SignalState.low,
          3: SignalState.low,
          4: SignalState.low, // ~1PRE active
          15: SignalState.high,
          5: SignalState.low,
          6: SignalState.high,
        },
        internalState: state,
      );
      expect(presetResult[5], SignalState.high);
      expect(presetResult[6], SignalState.low);

      final clearResult = chip.evaluate(
        {
          1: SignalState.low,
          2: SignalState.high,
          3: SignalState.high,
          4: SignalState.high,
          15: SignalState.low, // ~1CLR active
          5: SignalState.high,
          6: SignalState.low,
        },
        internalState: state,
      );
      expect(clearResult[5], SignalState.low);
      expect(clearResult[6], SignalState.high);
    });

    test('both async inputs low drive Q and ~Q high', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          1: SignalState.low,
          2: SignalState.low,
          3: SignalState.low,
          4: SignalState.low,
          15: SignalState.low,
          5: SignalState.low,
          6: SignalState.high,
        },
        internalState: state,
      );
      expect(result[5], SignalState.high);
      expect(result[6], SignalState.high);
    });

    test('no falling edge means the output holds', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['ff1_prev_clk'] = SignalState.low;

      // Clock stays low while J/K change: not an edge.
      var result = chip.evaluate(
        {
          1: SignalState.low,
          2: SignalState.low,
          3: SignalState.high,
          4: SignalState.high,
          15: SignalState.high,
          5: SignalState.low,
          6: SignalState.high,
        },
        internalState: state,
      );
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.high);

      // Low-to-high transition is not the active edge.
      result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.low,
          3: SignalState.high,
          4: SignalState.high,
          15: SignalState.high,
          5: SignalState.low,
          6: SignalState.high,
        },
        internalState: state,
      );
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.high);
    });

    test('unknown or highZ J at falling edge produces unknown outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        1: SignalState.high,
        2: SignalState.low,
        3: SignalState.unknown,
        4: SignalState.high,
        15: SignalState.high,
        5: SignalState.low,
        6: SignalState.high,
      };

      chip.evaluate(base, internalState: state);
      final unknownResult = chip.evaluate(
        {...base, 1: SignalState.low},
        internalState: state,
      );
      expect(unknownResult[5], SignalState.unknown);
      expect(unknownResult[6], SignalState.unknown);

      chip.evaluate({...base, 1: SignalState.high, 3: SignalState.highZ},
          internalState: state);
      final highZResult = chip.evaluate(
        {...base, 1: SignalState.low, 3: SignalState.highZ},
        internalState: state,
      );
      expect(highZResult[5], SignalState.unknown);
      expect(highZResult[6], SignalState.unknown);
    });

    test('second flip-flop toggles independently', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        13: SignalState.high, // 2CLK
        10: SignalState.high, // ~2PRE
        14: SignalState.low, // ~2CLR active
        11: SignalState.high, // 2J
        12: SignalState.high, // 2K
        9: SignalState.low, // 2Q
        7: SignalState.high, // ~2Q
      };
      chip.evaluate(base, internalState: state);

      final toggleResult = chip.evaluate(
        {...base, 14: SignalState.high, 13: SignalState.low},
        internalState: state,
      );
      expect(toggleResult[9], SignalState.high);
      expect(toggleResult[7], SignalState.low);
    });
  });
}
