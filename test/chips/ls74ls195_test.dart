import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls195.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS195 chip;

  setUp(() {
    chip = Chip74LS195();
  });

  group('Chip74LS195', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS195');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('~MR', 'input'),
        2: ('J', 'input'),
        3: ('~K', 'input'),
        4: ('P0', 'input'),
        5: ('P1', 'input'),
        6: ('P2', 'input'),
        7: ('P3', 'input'),
        8: ('GND', 'ground'),
        9: ('~PE', 'input'),
        10: ('CP', 'input'),
        11: ('~Q3', 'output'),
        12: ('Q3', 'output'),
        13: ('Q2', 'output'),
        14: ('Q1', 'output'),
        15: ('Q0', 'output'),
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

    test('~MR low asynchronously clears the register', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.high;
      state['q1'] = SignalState.high;
      state['q2'] = SignalState.high;
      state['q3'] = SignalState.high;
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.low,
          9: SignalState.high,
          10: SignalState.high,
          2: SignalState.high,
          3: SignalState.high,
        },
        internalState: state,
      );

      expect(result[15], SignalState.low);
      expect(result[14], SignalState.low);
      expect(result[13], SignalState.low);
      expect(result[12], SignalState.low);
      expect(result[11], SignalState.high, reason: '~Q3 complement');
    });

    test('~PE low loads P0-P3 in parallel on the rising edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          4: SignalState.high, // P0
          5: SignalState.low, // P1
          6: SignalState.high, // P2
          7: SignalState.low, // P3
          9: SignalState.low, // ~PE load
          10: SignalState.high, // rising edge
        },
        internalState: state,
      );

      expect(result[15], SignalState.high);
      expect(result[14], SignalState.low);
      expect(result[13], SignalState.high);
      expect(result[12], SignalState.low);
      expect(result[11], SignalState.high, reason: '~Q3 complement');
    });

    test('J=high, ~K=high sets the first stage on shift', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.low;
      }
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          3: SignalState.high,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );

      expect(result[15], SignalState.high, reason: 'set');
      expect(result[14], SignalState.low);
      expect(result[13], SignalState.low);
      expect(result[12], SignalState.low);
    });

    test('J=low, ~K=low resets the first stage on shift', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.high;
      }
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.low,
          3: SignalState.low,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );

      expect(result[15], SignalState.low, reason: 'reset');
      expect(result[14], SignalState.high);
      expect(result[13], SignalState.high);
      expect(result[12], SignalState.high);
    });

    test('J=high, ~K=low toggles the first stage on shift', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.low;
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          3: SignalState.low,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );

      expect(result[15], SignalState.high, reason: 'toggled from 0 to 1');
    });

    test('J=low, ~K=high holds the first stage on shift', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.high;
      state['q1'] = SignalState.low;
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.low,
          3: SignalState.high,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );

      expect(result[15], SignalState.high, reason: 'held');
      expect(result[14], SignalState.high, reason: 'old Q0 shifted right');
    });

    test('J tied to ~K behaves as a D serial input', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.low;
      }
      state['prev_clk'] = SignalState.low;

      // D=1 (J=1, ~K=1): set.
      var result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          3: SignalState.high,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );
      expect(result[15], SignalState.high);

      // Next edge D=0 (J=0, ~K=0): reset.
      state['prev_clk'] = SignalState.low;
      result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.low,
          3: SignalState.low,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );
      expect(result[15], SignalState.low);
      expect(result[14], SignalState.high, reason: 'previous Q0 shifted right');
    });

    test('no clock edge or unknown ~PE holds the register', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.high;
      state['q1'] = SignalState.low;
      state['q2'] = SignalState.low;
      state['q3'] = SignalState.low;
      state['prev_clk'] = SignalState.high;

      // Clock stays high: no edge.
      var result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.low,
          3: SignalState.low,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );
      expect(result[15], SignalState.high);
      expect(result[14], SignalState.low);

      // Unknown ~PE on a real edge: hold.
      state['prev_clk'] = SignalState.low;
      result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.low,
          3: SignalState.low,
          9: SignalState.unknown,
          10: SignalState.high,
        },
        internalState: state,
      );
      expect(result[15], SignalState.high);
      expect(result[14], SignalState.low);
    });

    test('unknown or highZ J or ~K shifts in unknown', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.low;
      }
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.highZ,
          3: SignalState.high,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );

      expect(result[15], SignalState.unknown);
      expect(result[14], SignalState.low);
      expect(result[13], SignalState.low);
      expect(result[12], SignalState.low);
    });
  });
}
