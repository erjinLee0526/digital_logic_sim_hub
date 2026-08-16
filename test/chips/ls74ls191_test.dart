import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls191.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS191 chip;

  setUp(() {
    chip = Chip74LS191();
  });

  group('Chip74LS191', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS191');
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

    test('counts up on rising CP and wraps from 15 to 0', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        11: SignalState.high,
        4: SignalState.low,
        5: SignalState.low, // count up
        14: SignalState.low,
        15: SignalState.high,
        1: SignalState.high,
        10: SignalState.high,
        9: SignalState.high,
      };

      // Load 15 (1111).
      chip.evaluate({...base, 11: SignalState.low}, internalState: state);

      var result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.low, reason: '15 + 1 wraps to 0');
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

    test('counts down on rising CP and wraps from 0 to 15', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        11: SignalState.high,
        4: SignalState.low,
        5: SignalState.high, // count down
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
      expect(result[3], SignalState.high, reason: '0 - 1 wraps to 15');
      expect(result[2], SignalState.high);
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.high);

      chip.evaluate(base, internalState: state);
      result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.low, reason: '15 - 1 = 14');
      expect(result[2], SignalState.high);
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.high);
    });

    test('~PL and ~CE async load and hold behave correctly', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        11: SignalState.high,
        4: SignalState.high, // ~CE inactive
        5: SignalState.low,
        14: SignalState.low,
        15: SignalState.high,
        1: SignalState.low,
        10: SignalState.high,
        9: SignalState.high,
      };

      // Load 13 (1101) regardless of CP/CE.
      chip.evaluate({...base, 11: SignalState.low}, internalState: state);
      var result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.high);
      expect(result[2], SignalState.low);
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.high);

      // Enable counting and verify the edge was not consumed while ~CE was
      // high: the next CP edge must still be required.
      result = chip.evaluate(
        {...base, 4: SignalState.low},
        internalState: state,
      );
      expect(result[3], SignalState.high, reason: 'still 13 while CP low');
      result = chip.evaluate(
        {...base, 4: SignalState.low, 14: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.low, reason: '13 + 1 = 14');
      expect(result[2], SignalState.high);
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.high);
    });

    test('TC is high only at the terminal count', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        11: SignalState.high,
        4: SignalState.low,
        5: SignalState.low,
        14: SignalState.low,
        15: SignalState.high,
        1: SignalState.high,
        10: SignalState.high,
        9: SignalState.high,
      };

      // Load 15 counting up: TC high.
      var result = chip.evaluate(
        {...base, 11: SignalState.low},
        internalState: state,
      );
      expect(result[12], SignalState.high, reason: 'TC at 15 counting up');

      // Count up 15 -> 0: TC drops.
      result = chip.evaluate(
        {...base, 14: SignalState.high},
        internalState: state,
      );
      expect(result[12], SignalState.low, reason: 'TC low at 0 counting up');

      // Switch to count-down at 0: TC high again (0 is the down terminal).
      result = chip.evaluate(
        {...base, 5: SignalState.high, 14: SignalState.low},
        internalState: state,
      );
      expect(result[12], SignalState.high,
          reason: 'TC high at 0 counting down');

      // Count down 0 -> 15: TC drops.
      result = chip.evaluate(
        {...base, 5: SignalState.high, 14: SignalState.high},
        internalState: state,
      );
      expect(result[12], SignalState.low, reason: '15 counting down is not TC');

      // Count down 15 -> 0.
      for (var i = 0; i < 15; i++) {
        chip.evaluate({...base, 5: SignalState.high, 14: SignalState.low},
            internalState: state);
        chip.evaluate({...base, 5: SignalState.high, 14: SignalState.high},
            internalState: state);
      }
      result = chip.evaluate(
        {...base, 5: SignalState.high, 14: SignalState.low},
        internalState: state,
      );
      expect(result[12], SignalState.high,
          reason: 'TC high at 0 counting down');
      expect(result[3], SignalState.low);
      expect(result[2], SignalState.low);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);
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
  });
}
