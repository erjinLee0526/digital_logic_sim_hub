import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls166.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS166 chip;

  setUp(() {
    chip = Chip74LS166();
  });

  group('Chip74LS166', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS166');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('SER', 'input'),
        2: ('A', 'input'),
        3: ('B', 'input'),
        4: ('C', 'input'),
        5: ('D', 'input'),
        6: ('CLK INH', 'input'),
        7: ('CLK', 'input'),
        8: ('GND', 'ground'),
        9: ('~CLR', 'input'),
        10: ('E', 'input'),
        11: ('F', 'input'),
        12: ('G', 'input'),
        13: ('H', 'input'),
        14: ('QH', 'output'),
        15: ('~SH/LD', 'input'),
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

    test('~CLR low asynchronously clears and overrides load and clock', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          9: SignalState.low, // ~CLR active
          15: SignalState.low, // ~SH/LD load
          6: SignalState.high, // CLK INH enabled
          7: SignalState.high, // rising edge
          13: SignalState.high, // H
          2: SignalState.high,
          3: SignalState.high,
          4: SignalState.high,
          5: SignalState.high,
          10: SignalState.high,
          11: SignalState.high,
          12: SignalState.high,
        },
        internalState: state,
      );

      expect(result[14], SignalState.low);
    });

    test('~SH/LD low loads A-H in parallel on the rising edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          9: SignalState.high,
          15: SignalState.low, // parallel load
          6: SignalState.high,
          7: SignalState.high, // rising edge
          2: SignalState.low, // A
          3: SignalState.low,
          4: SignalState.low,
          5: SignalState.low,
          10: SignalState.low,
          11: SignalState.low,
          12: SignalState.low,
          13: SignalState.high, // H -> QH should be high
        },
        internalState: state,
      );

      expect(result[14], SignalState.high);
    });

    test('~SH/LD high shifts right with SER entering the first stage', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 8; i++) {
        state['q$i'] = SignalState.low;
      }
      state['q6'] = SignalState.high; // G=1
      state['prev_clk'] = SignalState.low;

      var result = chip.evaluate(
        {
          9: SignalState.high,
          15: SignalState.high, // shift
          6: SignalState.high,
          7: SignalState.high, // rising edge
          1: SignalState.high, // SER
        },
        internalState: state,
      );
      // Old G (q6) moves into H (q7) and appears at QH.
      expect(result[14], SignalState.high);

      state['prev_clk'] = SignalState.low;
      result = chip.evaluate(
        {
          9: SignalState.high,
          15: SignalState.high,
          6: SignalState.high,
          7: SignalState.high,
          1: SignalState.low, // next SER is 0
        },
        internalState: state,
      );
      expect(result[14], SignalState.low, reason: 'the 1 shifted out');
    });

    test('CLK INH low holds the register despite a rising CLK edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q7'] = SignalState.high;
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          9: SignalState.high,
          15: SignalState.high,
          6: SignalState.low, // clock inhibited
          7: SignalState.high,
          1: SignalState.low,
        },
        internalState: state,
      );

      expect(result[14], SignalState.high);
    });

    test('no clock edge leaves QH unchanged', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q7'] = SignalState.low;
      state['prev_clk'] = SignalState.high;

      final result = chip.evaluate(
        {
          9: SignalState.high,
          15: SignalState.high,
          6: SignalState.high,
          7: SignalState.high, // stays high, no edge
          1: SignalState.high,
        },
        internalState: state,
      );

      expect(result[14], SignalState.low);
    });

    test('unknown or highZ serial or parallel data produces unknown QH', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.low;

      // Unknown H bit during parallel load.
      var result = chip.evaluate(
        {
          9: SignalState.high,
          15: SignalState.low,
          6: SignalState.high,
          7: SignalState.high,
          13: SignalState.unknown,
        },
        internalState: state,
      );
      expect(result[14], SignalState.unknown);

      // Shift unknown SER in until it reaches QH.
      for (var i = 0; i < 7; i++) {
        state['prev_clk'] = SignalState.low;
        chip.evaluate(
          {
            9: SignalState.high,
            15: SignalState.high,
            6: SignalState.high,
            7: SignalState.high,
            1: SignalState.unknown,
          },
          internalState: state,
        );
      }
      state['prev_clk'] = SignalState.low;
      result = chip.evaluate(
        {
          9: SignalState.high,
          15: SignalState.high,
          6: SignalState.high,
          7: SignalState.high,
          1: SignalState.unknown,
        },
        internalState: state,
      );
      expect(result[14], SignalState.unknown);
    });

    test('unknown ~SH/LD on the edge holds the register', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q7'] = SignalState.high;
      state['prev_clk'] = SignalState.low;

      final result = chip.evaluate(
        {
          9: SignalState.high,
          15: SignalState.unknown,
          6: SignalState.high,
          7: SignalState.high,
          1: SignalState.low,
        },
        internalState: state,
      );

      expect(result[14], SignalState.high);
    });
  });
}
