import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls194.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS194 chip;

  setUp(() {
    chip = Chip74LS194();
  });

  group('Chip74LS194', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS194');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('~MR', 'input'),
        2: ('DSR', 'input'),
        3: ('P0', 'input'),
        4: ('P1', 'input'),
        5: ('P2', 'input'),
        6: ('P3', 'input'),
        7: ('DSL', 'input'),
        8: ('GND', 'ground'),
        9: ('Q0', 'output'),
        10: ('Q1', 'output'),
        11: ('Q2', 'output'),
        12: ('Q3', 'output'),
        13: ('CP', 'input'),
        14: ('S0', 'input'),
        15: ('S1', 'input'),
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

    test('asynchronous clear overrides the clock edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          1: SignalState.low,
          13: SignalState.high,
          14: SignalState.high,
          15: SignalState.high,
        },
        internalState: state,
      );

      expect(result[9], SignalState.low);
      expect(result[10], SignalState.low);
      expect(result[11], SignalState.low);
      expect(result[12], SignalState.low);
    });

    test('S1/S0 = 00 holds the register on the clock edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.high;
      state['q1'] = SignalState.low;
      state['q2'] = SignalState.low;
      state['q3'] = SignalState.low;
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          13: SignalState.high,
          14: SignalState.low,
          15: SignalState.low,
        },
        internalState: state,
      );

      expect(result[9], SignalState.high);
      expect(result[10], SignalState.low);
    });

    test('S1/S0 = 01 shifts right with DSR entering Q0', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.high;
      state['q1'] = SignalState.low;
      state['q2'] = SignalState.low;
      state['q3'] = SignalState.low;
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.low,
          13: SignalState.high,
          14: SignalState.high,
          15: SignalState.low,
        },
        internalState: state,
      );

      expect(result[9], SignalState.low); // DSR
      expect(result[10], SignalState.high); // old Q0
      expect(result[11], SignalState.low);
      expect(result[12], SignalState.low);
    });

    test('S1/S0 = 10 shifts left with DSL entering Q3', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.low;
      state['q1'] = SignalState.low;
      state['q2'] = SignalState.low;
      state['q3'] = SignalState.high;
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          7: SignalState.low,
          13: SignalState.high,
          14: SignalState.low,
          15: SignalState.high,
        },
        internalState: state,
      );

      expect(result[9], SignalState.low);
      expect(result[10], SignalState.low);
      expect(result[11], SignalState.high); // old Q3
      expect(result[12], SignalState.low); // DSL
    });

    test('S1/S0 = 11 loads P0-P3 in parallel', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          1: SignalState.high,
          3: SignalState.high,
          4: SignalState.low,
          5: SignalState.high,
          6: SignalState.low,
          13: SignalState.high,
          14: SignalState.high,
          15: SignalState.high,
        },
        internalState: state,
      );

      expect(result[9], SignalState.high);
      expect(result[10], SignalState.low);
      expect(result[11], SignalState.high);
      expect(result[12], SignalState.low);
    });

    test('unknown mode select produces unknown outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.high;
      state['q1'] = SignalState.low;
      state['q2'] = SignalState.low;
      state['q3'] = SignalState.low;
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          13: SignalState.high,
          14: SignalState.unknown,
          15: SignalState.high,
        },
        internalState: state,
      );

      expect(result[9], SignalState.unknown);
      expect(result[10], SignalState.unknown);
      expect(result[11], SignalState.unknown);
      expect(result[12], SignalState.unknown);
    });

    test('unknown or highZ serial input shifts in unknown', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.low;
      }
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.highZ,
          13: SignalState.high,
          14: SignalState.high,
          15: SignalState.low,
        },
        internalState: state,
      );

      expect(result[9], SignalState.unknown);
      expect(result[10], SignalState.low);
      expect(result[11], SignalState.low);
      expect(result[12], SignalState.low);
    });
  });
}
