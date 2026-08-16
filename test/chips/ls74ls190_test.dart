import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls190.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS190 chip;

  setUp(() {
    chip = Chip74LS190();
  });

  group('Chip74LS190', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS190');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('P1', 'input'),
        2: ('Q1', 'output'),
        3: ('Q0', 'output'),
        4: ('~CE', 'input'),
        5: ('U/D', 'input'),
        6: ('Q2', 'output'),
        7: ('Q3', 'output'),
        8: ('GND', 'ground'),
        9: ('P3', 'input'),
        10: ('P2', 'input'),
        11: ('~PL', 'input'),
        12: ('TC', 'output'),
        13: ('RC', 'output'),
        14: ('CP', 'input'),
        15: ('P0', 'input'),
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

    test('asynchronous load overrides clock and control inputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          11: SignalState.low, // ~PL active
          15: SignalState.high, // P0
          1: SignalState.high, // P1
          10: SignalState.low, // P2
          9: SignalState.high, // P3 -> 1011 = 11
          14: SignalState.high, // CP
          4: SignalState.low, // ~CE
          5: SignalState.low, // U/D
        },
        internalState: state,
      );

      expect(result[3], SignalState.high);
      expect(result[2], SignalState.high);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.high);
    });

    test('counts up on rising CP and wraps from 9 to 0', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        11: SignalState.high, // ~PL
        15: SignalState.high, // P0 (unused while ~PL high)
        1: SignalState.low,
        10: SignalState.low,
        9: SignalState.high,
        4: SignalState.low, // ~CE active
        5: SignalState.low, // U/D = count up
        14: SignalState.low, // CP
      };

      // Load 9 (1001).
      chip.evaluate(
        {
          ...base,
          11: SignalState.low,
          15: SignalState.high,
          1: SignalState.low
        },
        internalState: state,
      );

      var result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.low, reason: '9 + 1 wraps to 0');
      expect(result[2], SignalState.low);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);

      chip.evaluate(base, internalState: state);
      result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.high, reason: '0 + 1 = 1');
      expect(result[2], SignalState.low);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);
    });

    test('counts down on rising CP and wraps from 0 to 9', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        11: SignalState.high,
        4: SignalState.low,
        5: SignalState.high, // U/D = count down
        14: SignalState.low,
        15: SignalState.low,
        1: SignalState.low,
        10: SignalState.low,
        9: SignalState.low,
      };

      // Load 0 (0000).
      chip.evaluate({...base, 11: SignalState.low}, internalState: state);

      var result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.high, reason: '0 - 1 wraps to 9');
      expect(result[2], SignalState.low);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.high);

      chip.evaluate(base, internalState: state);
      result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.low, reason: '9 - 1 = 8');
      expect(result[2], SignalState.low);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.high);
    });

    test('~CE high holds the count even on a rising CP edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        11: SignalState.high,
        4: SignalState.high, // ~CE inactive
        5: SignalState.low,
        14: SignalState.low,
        15: SignalState.high,
        1: SignalState.low,
        10: SignalState.high,
        9: SignalState.low,
      };

      // Load 5 (0101).
      chip.evaluate({...base, 11: SignalState.low}, internalState: state);
      final result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );

      expect(result[3], SignalState.high);
      expect(result[2], SignalState.low);
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.low);
    });

    test('TC and RC follow the terminal count', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        11: SignalState.high,
        15: SignalState.high,
        1: SignalState.low,
        10: SignalState.low,
        9: SignalState.high, // load value 9
        4: SignalState.low,
        5: SignalState.low, // count up
        14: SignalState.low,
      };

      var result = chip.evaluate(
        {...base, 11: SignalState.low},
        internalState: state,
      );
      expect(result[12], SignalState.high, reason: 'TC at 9 counting up');
      expect(result[13], SignalState.high, reason: 'RC high while CP low');

      // Hold at 9 with ~CE high and CP high.
      result = chip.evaluate(
        {...base, 4: SignalState.high, 14: SignalState.high},
        internalState: state,
      );
      expect(result[12], SignalState.high);
      expect(result[13], SignalState.high, reason: 'RC high while ~CE high');

      // ~CE low again with CP already high: no edge, RC pulses low.
      result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );
      expect(result[12], SignalState.high);
      expect(result[13], SignalState.low, reason: 'RC low at CP+~CE+TC');

      // Next rising edge counts 9 -> 0 and clears TC.
      result = chip.evaluate(base, internalState: state);
      expect(result[13], SignalState.high, reason: 'RC high while CP low');
      result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );
      expect(result[12], SignalState.low, reason: 'TC low away from 9');
      expect(result[13], SignalState.high, reason: 'RC high without TC');
    });

    test('unknown or highZ load data produces unknown outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          11: SignalState.low,
          15: SignalState.unknown,
          1: SignalState.high,
          10: SignalState.highZ,
          9: SignalState.high,
          14: SignalState.low,
        },
        internalState: state,
      );

      expect(result[3], SignalState.unknown);
      expect(result[2], SignalState.high);
      expect(result[6], SignalState.unknown);
      expect(result[7], SignalState.high);
    });

    test('unknown direction holds the count on a rising edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        11: SignalState.high,
        4: SignalState.low,
        5: SignalState.unknown,
        14: SignalState.low,
        15: SignalState.high,
        1: SignalState.high,
        10: SignalState.low,
        9: SignalState.low,
      };

      // Load 3 (0011).
      chip.evaluate({...base, 11: SignalState.low}, internalState: state);
      final result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );

      expect(result[3], SignalState.high);
      expect(result[2], SignalState.high);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);
    });
  });
}
