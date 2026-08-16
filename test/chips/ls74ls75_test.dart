import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls75.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS75 chip;

  setUp(() {
    chip = Chip74LS75();
  });

  group('Chip74LS75', () {
    test('has correct model and DIP-16 pinout', () {
      expect(chip.model, '74LS75');
      expect(chip.pinDefinitions.length, 16);

      const expected = {
        1: ('~Q0', 'output'),
        2: ('D0', 'input'),
        3: ('D1', 'input'),
        4: ('E2-3', 'input'),
        5: ('VCC', 'power'),
        6: ('D2', 'input'),
        7: ('D3', 'input'),
        8: ('~Q3', 'output'),
        9: ('Q3', 'output'),
        10: ('~Q2', 'output'),
        11: ('Q2', 'output'),
        12: ('GND', 'ground'),
        13: ('E0-1', 'input'),
        14: ('~Q1', 'output'),
        15: ('Q1', 'output'),
        16: ('Q0', 'output'),
      };

      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key} label');
        expect(pin.direction.name, entry.value.$2,
            reason: 'pin ${entry.key} direction');
      }
    });

    test('enable high makes the latch transparent with complements', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          13: SignalState.high, // E0-1
          4: SignalState.low, // E2-3
          2: SignalState.high, // D0
          3: SignalState.low, // D1
        },
        internalState: state,
      );

      expect(result[16], SignalState.high);
      expect(result[1], SignalState.low);
      expect(result[15], SignalState.low);
      expect(result[14], SignalState.high);
    });

    test('falling enable latches the last data value', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      chip.evaluate(
        {13: SignalState.high, 2: SignalState.high},
        internalState: state,
      );

      final result = chip.evaluate(
        {13: SignalState.low, 2: SignalState.low},
        internalState: state,
      );

      expect(result[16], SignalState.high, reason: 'retains latched value');
      expect(result[1], SignalState.low);
    });

    test('the two enable groups control their own latch pairs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          13: SignalState.high, // E0-1 transparent
          4: SignalState.low, // E2-3 latched
          2: SignalState.high,
          6: SignalState.high,
        },
        internalState: state,
      );

      expect(result[16], SignalState.high, reason: 'latch 0 follows D0');
      expect(result[11], SignalState.unknown,
          reason: 'latch 2 holds its power-up unknown');
    });

    test('unknown enable produces unknown outputs without destroying storage',
        () {
      final state = Map<String, SignalState>.of(chip.initialState);
      chip.evaluate(
        {13: SignalState.high, 2: SignalState.high},
        internalState: state,
      );

      var result = chip.evaluate(
        {13: SignalState.unknown, 2: SignalState.low},
        internalState: state,
      );
      expect(result[16], SignalState.unknown);
      expect(result[1], SignalState.unknown);

      // Returning to a definite low enable recovers the stored value.
      result = chip.evaluate(
        {13: SignalState.low, 2: SignalState.low},
        internalState: state,
      );
      expect(result[16], SignalState.high);
    });

    test('unknown or highZ D while enabled gives unknown outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          13: SignalState.high,
          2: SignalState.unknown,
          3: SignalState.highZ,
        },
        internalState: state,
      );

      expect(result[16], SignalState.unknown);
      expect(result[1], SignalState.unknown);
      expect(result[15], SignalState.unknown);
      expect(result[14], SignalState.unknown);
    });

    test('complementary outputs stay opposite for latched values', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      chip.evaluate(
        {4: SignalState.high, 7: SignalState.low},
        internalState: state,
      );

      final result = chip.evaluate(
        {4: SignalState.low, 7: SignalState.high},
        internalState: state,
      );

      expect(result[9], SignalState.low);
      expect(result[8], SignalState.high);
    });
  });
}
