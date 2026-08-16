import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls374.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS374 chip;

  setUp(() {
    chip = Chip74LS374();
  });

  group('Chip74LS374', () {
    test('has correct model and DIP-20 pinout', () {
      expect(chip.model, '74LS374');
      expect(chip.pinDefinitions.length, 20);

      const expected = {
        1: ('~OE', 'input'),
        2: ('Q0', 'output'),
        3: ('D0', 'input'),
        4: ('D1', 'input'),
        5: ('Q1', 'output'),
        6: ('Q2', 'output'),
        7: ('D2', 'input'),
        8: ('D3', 'input'),
        9: ('Q3', 'output'),
        10: ('GND', 'ground'),
        11: ('CP', 'input'),
        12: ('Q4', 'output'),
        13: ('D4', 'input'),
        14: ('D5', 'input'),
        15: ('Q5', 'output'),
        16: ('Q6', 'output'),
        17: ('D6', 'input'),
        18: ('D7', 'input'),
        19: ('Q7', 'output'),
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

    test('CP rising edge latches all eight D inputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.low,
          3: SignalState.high,
          4: SignalState.low,
          7: SignalState.high,
          8: SignalState.low,
          13: SignalState.high,
          14: SignalState.low,
          17: SignalState.high,
          18: SignalState.low,
          11: SignalState.high,
        },
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

    test('D changes without a clock edge do not update the storage', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.low;

      chip.evaluate(
        {1: SignalState.low, 3: SignalState.high, 11: SignalState.high},
        internalState: state,
      );
      expect(state['q0'], SignalState.high);

      // Clock stays high, D drops: no edge, value must stay latched.
      final result = chip.evaluate(
        {1: SignalState.low, 3: SignalState.low, 11: SignalState.high},
        internalState: state,
      );
      expect(result[2], SignalState.high);
      expect(state['q0'], SignalState.high);
    });

    test('~OE high puts every output in high impedance', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.high;
      state['q1'] = SignalState.low;
      state['prev_clk'] = SignalState.high;

      final result = chip.evaluate(
        {1: SignalState.high, 11: SignalState.low},
        internalState: state,
      );

      for (final pin in [2, 5, 6, 9, 12, 15, 16, 19]) {
        expect(result[pin], SignalState.highZ, reason: 'pin $pin');
      }
    });

    test('unknown ~OE produces unknown outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.high;
      state['prev_clk'] = SignalState.high;

      final result = chip.evaluate(
        {1: SignalState.unknown, 11: SignalState.low},
        internalState: state,
      );

      expect(result[2], SignalState.unknown);
      expect(result[5], SignalState.unknown);
    });

    test('unknown or highZ D on the edge latches unknown', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.low,
          3: SignalState.unknown,
          4: SignalState.highZ,
          11: SignalState.high,
        },
        internalState: state,
      );

      expect(result[2], SignalState.unknown);
      expect(result[5], SignalState.unknown);
    });

    test('toggling ~OE does not disturb the internal latch', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.low;

      chip.evaluate(
        {1: SignalState.low, 3: SignalState.high, 11: SignalState.high},
        internalState: state,
      );
      expect(state['q0'], SignalState.high);

      final disabled = chip.evaluate(
        {1: SignalState.high, 3: SignalState.low, 11: SignalState.low},
        internalState: state,
      );
      expect(disabled[2], SignalState.highZ);
      expect(state['q0'], SignalState.high, reason: 'latch unchanged');

      final enabledAgain = chip.evaluate(
        {1: SignalState.low, 3: SignalState.low, 11: SignalState.low},
        internalState: state,
      );
      expect(enabledAgain[2], SignalState.high);
    });
  });
}
