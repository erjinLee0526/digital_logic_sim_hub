import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls161.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS161 chip;

  setUp(() {
    chip = Chip74LS161();
  });

  group('Chip74LS161', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS161');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('~CLR', 'input'),
        2: ('CLK', 'input'),
        3: ('P0', 'input'),
        4: ('P1', 'input'),
        5: ('P2', 'input'),
        6: ('P3', 'input'),
        7: ('ENP', 'input'),
        8: ('GND', 'ground'),
        9: ('~LOAD', 'input'),
        10: ('ENT', 'input'),
        11: ('Q0', 'output'),
        12: ('Q1', 'output'),
        13: ('Q2', 'output'),
        14: ('Q3', 'output'),
        15: ('RCO', 'output'),
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

    test('asynchronous clear overrides clock and clears to 0000', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          1: SignalState.low,
          2: SignalState.high,
          7: SignalState.high,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );

      expect(result[11], SignalState.low);
      expect(result[12], SignalState.low);
      expect(result[13], SignalState.low);
      expect(result[14], SignalState.low);
      expect(result[15], SignalState.low);
    });

    test('rising edge synchronously loads P0-P3 when ~LOAD is low', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          3: SignalState.high,
          4: SignalState.low,
          5: SignalState.high,
          6: SignalState.low,
          7: SignalState.high,
          9: SignalState.low,
          10: SignalState.high,
        },
        internalState: state,
      );

      expect(result[11], SignalState.high);
      expect(result[12], SignalState.low);
      expect(result[13], SignalState.high);
      expect(result[14], SignalState.low);
      expect(result[15], SignalState.low);
    });

    test('counts on rising CLK when ENP and ENT are both high', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.low;
      }
      state['prev_clk'] = SignalState.low;

      Map<int, SignalState> pulse() {
        return chip.evaluate(
          {
            1: SignalState.high,
            2: SignalState.high,
            7: SignalState.high,
            9: SignalState.high,
            10: SignalState.high,
          },
          internalState: state,
        );
      }

      final first = pulse();
      expect(first[11], SignalState.high);
      expect(first[12], SignalState.low);

      chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.low,
          7: SignalState.high,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );
      final second = pulse();
      expect(second[11], SignalState.low);
      expect(second[12], SignalState.high);
    });

    test('holds current value when ENP or ENT is low', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.high;
      state['q1'] = SignalState.low;
      state['q2'] = SignalState.low;
      state['q3'] = SignalState.low;
      state['prev_clk'] = SignalState.low;

      final enpLow = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          7: SignalState.low,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );
      expect(enpLow[11], SignalState.high);
      expect(enpLow[12], SignalState.low);

      state['prev_clk'] = SignalState.low;
      final entLow = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          7: SignalState.high,
          9: SignalState.high,
          10: SignalState.low,
        },
        internalState: state,
      );
      expect(entLow[11], SignalState.high);
      expect(entLow[12], SignalState.low);
      expect(entLow[15], SignalState.low);
    });

    test('RCO is high only when ENT and all Q outputs are high', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.high;
      }

      final high = chip.evaluate(
        {1: SignalState.high, 10: SignalState.high},
        internalState: state,
      );
      expect(high[15], SignalState.high);

      final low = chip.evaluate(
        {1: SignalState.high, 10: SignalState.low},
        internalState: state,
      );
      expect(low[15], SignalState.low);
    });

    test('rolls over from 1111 to 0000', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.high;
      }
      state['prev_clk'] = SignalState.low;

      final before = chip.evaluate(
        {1: SignalState.high, 10: SignalState.high},
        internalState: state,
      );
      expect(before[15], SignalState.high);

      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          7: SignalState.high,
          9: SignalState.high,
          10: SignalState.high,
        },
        internalState: state,
      );
      expect(result[11], SignalState.low);
      expect(result[12], SignalState.low);
      expect(result[13], SignalState.low);
      expect(result[14], SignalState.low);
      expect(result[15], SignalState.low);
    });

    test('unknown or highZ load data produces unknown outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_clk'] = SignalState.low;
      final unknownResult = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          3: SignalState.unknown,
          9: SignalState.low,
        },
        internalState: state,
      );
      expect(unknownResult[11], SignalState.unknown);

      state['prev_clk'] = SignalState.low;
      final highZResult = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.high,
          3: SignalState.highZ,
          9: SignalState.low,
        },
        internalState: state,
      );
      expect(highZResult[11], SignalState.unknown);
    });
  });
}
