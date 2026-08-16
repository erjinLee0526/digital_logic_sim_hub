import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls193.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS193 chip;

  setUp(() {
    chip = Chip74LS193();
  });

  group('Chip74LS193', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS193');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('P1', 'input'),
        2: ('Q1', 'output'),
        3: ('Q0', 'output'),
        4: ('CPD', 'input'),
        5: ('CPU', 'input'),
        6: ('Q2', 'output'),
        7: ('Q3', 'output'),
        8: ('GND', 'ground'),
        9: ('P3', 'input'),
        10: ('P2', 'input'),
        11: ('~PL', 'input'),
        12: ('TCU', 'output'),
        13: ('TCD', 'output'),
        14: ('MR', 'input'),
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

    test('MR high asynchronously clears and overrides ~PL and clocks', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          14: SignalState.high, // MR active
          11: SignalState.low, // ~PL active
          15: SignalState.high,
          1: SignalState.high,
          10: SignalState.high,
          9: SignalState.high,
          5: SignalState.high, // CPU
          4: SignalState.high, // CPD
        },
        internalState: state,
      );

      expect(result[3], SignalState.low);
      expect(result[2], SignalState.low);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);
    });

    test('~PL low asynchronously loads when MR is low', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          14: SignalState.low,
          11: SignalState.low,
          15: SignalState.high, // P0
          1: SignalState.low, // P1
          10: SignalState.high, // P2
          9: SignalState.high, // P3 -> 1101 = 13
          5: SignalState.low,
          4: SignalState.low,
        },
        internalState: state,
      );

      expect(result[3], SignalState.high);
      expect(result[2], SignalState.low);
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.high);
    });

    test('counts up on CPU rising edges while CPD is high', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        14: SignalState.low,
        11: SignalState.high,
        15: SignalState.high,
        1: SignalState.high,
        10: SignalState.high,
        9: SignalState.high,
        4: SignalState.high, // CPD idle high
        5: SignalState.low, // CPU low
      };

      // Load 14 (1110).
      chip.evaluate(
        {
          ...base,
          11: SignalState.low,
          9: SignalState.high,
          10: SignalState.high,
          1: SignalState.high,
          15: SignalState.low
        },
        internalState: state,
      );

      var result = chip.evaluate(
        {...base, 5: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.high, reason: '14 + 1 = 15');
      expect(result[2], SignalState.high);
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.high);

      chip.evaluate(base, internalState: state);
      result = chip.evaluate(
        {...base, 5: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.low, reason: '15 + 1 wraps to 0');
      expect(result[2], SignalState.low);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);
    });

    test('counts down on CPD rising edges while CPU is high', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        14: SignalState.low,
        11: SignalState.high,
        15: SignalState.low,
        1: SignalState.low,
        10: SignalState.low,
        9: SignalState.low,
        5: SignalState.high, // CPU idle high
        4: SignalState.low, // CPD low
      };

      // Load 1 (0001).
      chip.evaluate(
        {...base, 11: SignalState.low, 15: SignalState.high},
        internalState: state,
      );

      var result = chip.evaluate(
        {...base, 4: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.low, reason: '1 - 1 = 0');
      expect(result[2], SignalState.low);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);

      chip.evaluate(base, internalState: state);
      result = chip.evaluate(
        {...base, 4: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.high, reason: '0 - 1 wraps to 15');
      expect(result[2], SignalState.high);
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.high);
    });

    test('inactive clock low prevents counting on the active edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        14: SignalState.low,
        11: SignalState.high,
        15: SignalState.high,
        1: SignalState.high,
        10: SignalState.low,
        9: SignalState.low,
        4: SignalState.low, // CPD low
        5: SignalState.low,
      };

      // Load 3 (0011).
      chip.evaluate({...base, 11: SignalState.low}, internalState: state);
      final result = chip.evaluate(
        {...base, 5: SignalState.high}, // CPU rises but CPD is low
        internalState: state,
      );

      expect(result[3], SignalState.high);
      expect(result[2], SignalState.high);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);
    });

    test('TCU and TCD track terminal counts and clock levels', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        14: SignalState.low,
        11: SignalState.high,
        15: SignalState.high,
        1: SignalState.high,
        10: SignalState.high,
        9: SignalState.high,
        4: SignalState.high, // CPD high
        5: SignalState.low, // CPU low
      };

      // Load 15 (1111): TCU low while CPU is low.
      var result = chip.evaluate(
        {...base, 11: SignalState.low},
        internalState: state,
      );
      expect(result[12], SignalState.low, reason: 'TCU low at 15 with CPU low');
      expect(result[13], SignalState.high, reason: 'TCD high elsewhere');

      // Raise CPU with CPD low: edge suppressed, count stays 15.
      result = chip.evaluate(
        {...base, 4: SignalState.low, 5: SignalState.high},
        internalState: state,
      );
      expect(result[12], SignalState.high, reason: 'TCU high while CPU high');
      expect(result[13], SignalState.high, reason: 'TCD high while CPD low');

      // Load 0 (0000): TCD low while CPD is low.
      result = chip.evaluate(
        {
          ...base,
          11: SignalState.low,
          15: SignalState.low,
          1: SignalState.low,
          10: SignalState.low,
          9: SignalState.low,
          5: SignalState.high,
          4: SignalState.low
        },
        internalState: state,
      );
      expect(result[12], SignalState.high, reason: 'TCU high away from 15');
      expect(result[13], SignalState.low, reason: 'TCD low at 0 with CPD low');
    });

    test('unknown or highZ load data produces unknown outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          14: SignalState.low,
          11: SignalState.low,
          15: SignalState.unknown,
          1: SignalState.high,
          10: SignalState.highZ,
          9: SignalState.high,
          5: SignalState.low,
          4: SignalState.low,
        },
        internalState: state,
      );

      expect(result[3], SignalState.unknown);
      expect(result[2], SignalState.high);
      expect(result[6], SignalState.unknown);
      expect(result[7], SignalState.high);
    });
  });
}
