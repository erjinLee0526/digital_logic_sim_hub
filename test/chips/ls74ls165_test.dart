import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls165.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS165 chip;

  setUp(() {
    chip = Chip74LS165();
  });

  group('Chip74LS165', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS165');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('~PL', 'input'),
        2: ('CLK', 'input'),
        3: ('E', 'input'),
        4: ('F', 'input'),
        5: ('G', 'input'),
        6: ('H', 'input'),
        7: ('~QH', 'output'),
        8: ('GND', 'ground'),
        9: ('QH', 'output'),
        10: ('SER', 'input'),
        11: ('A', 'input'),
        12: ('B', 'input'),
        13: ('C', 'input'),
        14: ('D', 'input'),
        15: ('CLK INH', 'input'),
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

    test('~PL low asynchronously loads parallel inputs A-H', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          1: SignalState.low,
          3: SignalState.low,
          4: SignalState.low,
          5: SignalState.low,
          6: SignalState.high,
          11: SignalState.high,
          12: SignalState.low,
          13: SignalState.low,
          14: SignalState.low,
        },
        internalState: state,
      );

      // H=1, so QH=1 and ~QH=0.
      expect(result[9], SignalState.high);
      expect(result[7], SignalState.low);
    });

    test('rising CLK shifts SER toward QH while CLK INH is low', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 8; i++) {
        state['q$i'] = SignalState.low;
      }
      state['q6'] = SignalState.high; // G=1, H=0 initially
      state['prev_clk'] = SignalState.low;
      state['prev_inh'] = SignalState.low;

      var result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          10: SignalState.high,
          15: SignalState.low,
        },
        internalState: state,
      );
      // The 1 in G shifts into H, so QH rises.
      expect(result[9], SignalState.high);

      state['prev_clk'] = SignalState.low;
      result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          10: SignalState.low,
          15: SignalState.low,
        },
        internalState: state,
      );
      // The previous bit in H has shifted out and QH now shows the next bit.
      expect(result[9], SignalState.low);
      expect(result[7], SignalState.high);
    });

    test('rising CLK INH shifts while CLK is low', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 8; i++) {
        state['q$i'] = SignalState.low;
      }
      state['q6'] = SignalState.high;
      state['prev_clk'] = SignalState.low;
      state['prev_inh'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.low,
          10: SignalState.low,
          15: SignalState.high,
        },
        internalState: state,
      );

      expect(result[9], SignalState.high);
    });

    test('no shift when the complementary clock input is high', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 8; i++) {
        state['q$i'] = SignalState.low;
      }
      state['q7'] = SignalState.high;
      state['prev_clk'] = SignalState.low;
      state['prev_inh'] = SignalState.low;

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          10: SignalState.low,
          15: SignalState.high,
        },
        internalState: state,
      );

      expect(result[9], SignalState.high);
    });

    test('unknown or highZ SER produces unknown QH after enough shifts', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 8; i++) {
        state['q$i'] = SignalState.low;
      }
      state['prev_clk'] = SignalState.low;
      state['prev_inh'] = SignalState.low;

      // Shift unknown SER into A eight times so it reaches QH.
      for (var i = 0; i < 8; i++) {
        state['prev_clk'] = SignalState.low;
        chip.evaluate(
          {
            1: SignalState.high,
            2: SignalState.high,
            10: SignalState.unknown,
            15: SignalState.low,
          },
          internalState: state,
        );
      }
      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          10: SignalState.unknown,
          15: SignalState.low,
        },
        internalState: state,
      );
      expect(result[9], SignalState.unknown);
      expect(result[7], SignalState.unknown);
    });
  });
}
