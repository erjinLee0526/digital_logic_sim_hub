import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls164.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS164 chip;

  setUp(() {
    chip = Chip74LS164();
  });

  group('Chip74LS164', () {
    test('has correct model and DIP-14 pinout', () {
      expect(chip.model, '74LS164');
      expect(chip.pinDefinitions.length, 14);

      const expected = {
        1: ('A', 'input'),
        2: ('B', 'input'),
        3: ('Q0', 'output'),
        4: ('Q1', 'output'),
        5: ('Q2', 'output'),
        6: ('Q3', 'output'),
        7: ('GND', 'ground'),
        8: ('CP', 'input'),
        9: ('~MR', 'input'),
        10: ('Q4', 'output'),
        11: ('Q5', 'output'),
        12: ('Q6', 'output'),
        13: ('Q7', 'output'),
        14: ('VCC', 'power'),
      };

      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key} label');
        expect(pin.direction.name, entry.value.$2,
            reason: 'pin ${entry.key} direction');
      }
    });

    test('asynchronous clear overrides the clock edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          8: SignalState.high,
          9: SignalState.low,
        },
        internalState: state,
      );

      for (final pin in [3, 4, 5, 6, 10, 11, 12, 13]) {
        expect(result[pin], SignalState.low, reason: 'pin $pin');
      }
    });

    test('rising edge shifts A AND B from Q0 toward Q7', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 8; i++) {
        state['q$i'] = SignalState.low;
      }
      state['prev_clk'] = SignalState.low;

      // First edge: serial 1 enters Q0.
      var result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          8: SignalState.high,
          9: SignalState.high,
        },
        internalState: state,
      );
      expect(result[3], SignalState.high);
      expect(result[4], SignalState.low);

      // Second edge: serial 0 enters Q0, the old 1 moves to Q1.
      result = chip.evaluate(
        {
          1: SignalState.low,
          2: SignalState.high,
          8: SignalState.low,
          9: SignalState.high,
        },
        internalState: state,
      );
      result = chip.evaluate(
        {
          1: SignalState.low,
          2: SignalState.high,
          8: SignalState.high,
          9: SignalState.high,
        },
        internalState: state,
      );
      expect(result[3], SignalState.low);
      expect(result[4], SignalState.high);
    });

    test('outputs hold while CP is not on a rising edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 8; i++) {
        state['q$i'] = SignalState.low;
      }
      state['q0'] = SignalState.high;
      state['prev_clk'] = SignalState.high;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          8: SignalState.high,
          9: SignalState.high,
        },
        internalState: state,
      );

      expect(result[3], SignalState.high);
      expect(result[4], SignalState.low);
    });

    test('serial input is the AND of A and B', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 8; i++) {
        state['q$i'] = SignalState.low;
      }
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.low,
          8: SignalState.high,
          9: SignalState.high,
        },
        internalState: state,
      );

      expect(result[3], SignalState.low);
    });

    test('unknown or highZ serial input produces unknown Q0', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 8; i++) {
        state['q$i'] = SignalState.low;
      }

      state['prev_clk'] = SignalState.low;
      final unknownResult = chip.evaluate(
        {
          1: SignalState.unknown,
          2: SignalState.high,
          8: SignalState.high,
          9: SignalState.high,
        },
        internalState: state,
      );
      expect(unknownResult[3], SignalState.unknown);

      state['prev_clk'] = SignalState.low;
      final highZResult = chip.evaluate(
        {
          1: SignalState.highZ,
          2: SignalState.high,
          8: SignalState.high,
          9: SignalState.high,
        },
        internalState: state,
      );
      expect(highZResult[3], SignalState.unknown);
    });
  });
}
