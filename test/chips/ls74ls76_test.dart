import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls76.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS76 chip;

  setUp(() {
    chip = Chip74LS76();
  });

  group('Chip74LS76', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS76');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('1CLK', 'input'),
        2: ('~1PRE', 'input'),
        3: ('~1CLR', 'input'),
        4: ('1J', 'input'),
        5: ('VCC', 'power'),
        6: ('2CLK', 'input'),
        7: ('~2PRE', 'input'),
        8: ('~2CLR', 'input'),
        9: ('2J', 'input'),
        10: ('~2Q', 'output'),
        11: ('2Q', 'output'),
        12: ('2K', 'input'),
        13: ('GND', 'ground'),
        14: ('~1Q', 'output'),
        15: ('1Q', 'output'),
        16: ('1K', 'input'),
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
        2: SignalState.high, // ~1PRE inactive
        3: SignalState.low, // ~1CLR active
        4: SignalState.low, // 1J
        16: SignalState.low, // 1K
        15: SignalState.unknown, // 1Q
        14: SignalState.unknown, // ~1Q
      };
      var result = chip.evaluate(inputs, internalState: state);
      expect(result[15], SignalState.low);
      expect(result[14], SignalState.high);

      // J=1, K=0: set on the falling edge.
      inputs = {
        1: SignalState.high,
        2: SignalState.high,
        3: SignalState.high,
        4: SignalState.high,
        16: SignalState.low,
        15: SignalState.low,
        14: SignalState.high,
      };
      chip.evaluate(inputs, internalState: state);
      result = chip.evaluate(
        {...inputs, 1: SignalState.low},
        internalState: state,
      );
      expect(result[15], SignalState.high);
      expect(result[14], SignalState.low);

      // J=0, K=1: reset on the falling edge.
      inputs = {
        1: SignalState.high,
        2: SignalState.high,
        3: SignalState.high,
        4: SignalState.low,
        16: SignalState.high,
        15: SignalState.high,
        14: SignalState.low,
      };
      chip.evaluate(inputs, internalState: state);
      result = chip.evaluate(
        {...inputs, 1: SignalState.low},
        internalState: state,
      );
      expect(result[15], SignalState.low);
      expect(result[14], SignalState.high);

      // J=K=1: toggle on each falling edge.
      inputs = {
        1: SignalState.high,
        2: SignalState.high,
        3: SignalState.high,
        4: SignalState.high,
        16: SignalState.high,
        15: SignalState.low,
        14: SignalState.high,
      };
      chip.evaluate(inputs, internalState: state);
      result = chip.evaluate(
        {...inputs, 1: SignalState.low},
        internalState: state,
      );
      expect(result[15], SignalState.high);
      expect(result[14], SignalState.low);
      inputs = {
        ...inputs,
        1: SignalState.high,
        15: result[15]!,
        14: result[14]!,
      };
      chip.evaluate(inputs, internalState: state);
      result = chip.evaluate(
        {...inputs, 1: SignalState.low},
        internalState: state,
      );
      expect(result[15], SignalState.low);
      expect(result[14], SignalState.high);

      // J=K=0: hold on the falling edge.
      inputs = {
        1: SignalState.high,
        2: SignalState.high,
        3: SignalState.high,
        4: SignalState.low,
        16: SignalState.low,
        15: SignalState.low,
        14: SignalState.high,
      };
      chip.evaluate(inputs, internalState: state);
      result = chip.evaluate(
        {...inputs, 1: SignalState.low},
        internalState: state,
      );
      expect(result[15], SignalState.low);
      expect(result[14], SignalState.high);
    });

    test('asynchronous preset and clear override the clock', () {
      final state = Map<String, SignalState>.of(chip.initialState);

      final presetResult = chip.evaluate(
        {
          1: SignalState.low, // falling edge from unknown
          2: SignalState.low, // ~1PRE active
          3: SignalState.high,
          4: SignalState.low,
          16: SignalState.low,
          15: SignalState.low,
          14: SignalState.high,
        },
        internalState: state,
      );
      expect(presetResult[15], SignalState.high);
      expect(presetResult[14], SignalState.low);

      final clearResult = chip.evaluate(
        {
          1: SignalState.low,
          2: SignalState.high,
          3: SignalState.low, // ~1CLR active
          4: SignalState.high,
          16: SignalState.high,
          15: SignalState.high,
          14: SignalState.low,
        },
        internalState: state,
      );
      expect(clearResult[15], SignalState.low);
      expect(clearResult[14], SignalState.high);
    });

    test('both async inputs low drive Q and ~Q high', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          1: SignalState.low,
          2: SignalState.low,
          3: SignalState.low,
          4: SignalState.low,
          16: SignalState.low,
          15: SignalState.low,
          14: SignalState.high,
        },
        internalState: state,
      );
      expect(result[15], SignalState.high);
      expect(result[14], SignalState.high);
    });

    test('no falling edge means the output holds', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['ff1_prev_clk'] = SignalState.low;

      // Clock stays low while J/K change: not an edge.
      var result = chip.evaluate(
        {
          1: SignalState.low,
          2: SignalState.high,
          3: SignalState.high,
          4: SignalState.high,
          16: SignalState.low,
          15: SignalState.low,
          14: SignalState.high,
        },
        internalState: state,
      );
      expect(result[15], SignalState.low);
      expect(result[14], SignalState.high);

      // Low-to-high transition is not the active edge.
      result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          3: SignalState.high,
          4: SignalState.high,
          16: SignalState.low,
          15: SignalState.low,
          14: SignalState.high,
        },
        internalState: state,
      );
      expect(result[15], SignalState.low);
      expect(result[14], SignalState.high);
    });

    test('unknown or highZ J at falling edge produces unknown outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        1: SignalState.high,
        2: SignalState.high,
        3: SignalState.high,
        4: SignalState.unknown,
        16: SignalState.low,
        15: SignalState.low,
        14: SignalState.high,
      };

      chip.evaluate(base, internalState: state);
      final unknownResult = chip.evaluate(
        {...base, 1: SignalState.low},
        internalState: state,
      );
      expect(unknownResult[15], SignalState.unknown);
      expect(unknownResult[14], SignalState.unknown);

      chip.evaluate({...base, 1: SignalState.high, 4: SignalState.highZ},
          internalState: state);
      final highZResult = chip.evaluate(
        {...base, 1: SignalState.low, 4: SignalState.highZ},
        internalState: state,
      );
      expect(highZResult[15], SignalState.unknown);
      expect(highZResult[14], SignalState.unknown);
    });

    test('second flip-flop toggles independently', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        6: SignalState.high, // 2CLK
        7: SignalState.high, // ~2PRE
        8: SignalState.low, // ~2CLR active
        9: SignalState.high, // 2J
        12: SignalState.high, // 2K
        11: SignalState.low, // 2Q
        10: SignalState.high, // ~2Q
      };
      chip.evaluate(base, internalState: state);

      final toggleResult = chip.evaluate(
        {...base, 8: SignalState.high, 6: SignalState.low},
        internalState: state,
      );
      expect(toggleResult[11], SignalState.high);
      expect(toggleResult[10], SignalState.low);
    });
  });
}
