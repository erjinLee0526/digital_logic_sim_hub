import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls90.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS90 chip;

  setUp(() {
    chip = Chip74LS90();
  });

  group('Chip74LS90', () {
    test('has correct model and DIP-14 pinout (NC pins unmodeled)', () {
      expect(chip.model, '74LS90');
      expect(chip.pinDefinitions.length, 12);

      const expected = {
        1: ('CKB', 'input'),
        2: ('R0(1)', 'input'),
        3: ('R0(2)', 'input'),
        5: ('VCC', 'power'),
        6: ('R9(1)', 'input'),
        7: ('R9(2)', 'input'),
        8: ('QC', 'output'),
        9: ('QB', 'output'),
        10: ('GND', 'ground'),
        11: ('QD', 'output'),
        12: ('QA', 'output'),
        14: ('CKA', 'input'),
      };

      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key} label');
        expect(pin.direction.name, entry.value.$2,
            reason: 'pin ${entry.key} direction');
      }

      expect(chip.pinDefinitions.any((p) => p.number == 4), isFalse);
      expect(chip.pinDefinitions.any((p) => p.number == 13), isFalse);
    });

    test('R0(1)=R0(2)=high asynchronously clears to 0000', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {2: SignalState.high, 3: SignalState.high},
        internalState: state,
      );

      expect(result[12], SignalState.low); // QA
      expect(result[9], SignalState.low); // QB
      expect(result[8], SignalState.low); // QC
      expect(result[11], SignalState.low); // QD
    });

    test('R9(1)=R9(2)=high asynchronously sets to 1001 (9)', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {6: SignalState.high, 7: SignalState.high},
        internalState: state,
      );

      expect(result[12], SignalState.high);
      expect(result[9], SignalState.low);
      expect(result[8], SignalState.low);
      expect(result[11], SignalState.high);
    });

    test('set-to-9 has priority over reset when both pairs are high', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          2: SignalState.high,
          3: SignalState.high,
          6: SignalState.high,
          7: SignalState.high,
        },
        internalState: state,
      );

      expect(result[12], SignalState.high);
      expect(result[9], SignalState.low);
      expect(result[8], SignalState.low);
      expect(result[11], SignalState.high);
    });

    test('falling CKA toggles the divide-by-2 QA output', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['qa'] = SignalState.low;
      state['qb'] = SignalState.low;
      state['qc'] = SignalState.low;
      state['qd'] = SignalState.low;
      state['prev_cka'] = SignalState.high;

      final first = chip.evaluate(
        {14: SignalState.low},
        internalState: state,
      );
      expect(first[12], SignalState.high);
      expect(first[11], SignalState.low);

      chip.evaluate({14: SignalState.high}, internalState: state);
      final second = chip.evaluate(
        {14: SignalState.low},
        internalState: state,
      );
      expect(second[12], SignalState.low);
    });

    test('falling CKB advances QB/QC/QD through 0-1-2-3-4-0', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['qa'] = SignalState.low;
      state['qb'] = SignalState.low;
      state['qc'] = SignalState.low;
      state['qd'] = SignalState.low;
      state['prev_ckb'] = SignalState.high;

      // Each falling edge produces the next divide-by-5 state.
      const expectedStates = [
        (SignalState.high, SignalState.low, SignalState.low),
        (SignalState.low, SignalState.high, SignalState.low),
        (SignalState.high, SignalState.high, SignalState.low),
        (SignalState.low, SignalState.low, SignalState.high),
        (SignalState.low, SignalState.low, SignalState.low),
      ];

      for (final (qb, qc, qd) in expectedStates) {
        chip.evaluate({1: SignalState.high}, internalState: state);
        final result = chip.evaluate(
          {1: SignalState.low},
          internalState: state,
        );
        expect(result[9], qb, reason: 'QB');
        expect(result[8], qc, reason: 'QC');
        expect(result[11], qd, reason: 'QD');
      }
    });

    test('rising clock edges do not change the count', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['qa'] = SignalState.low;
      state['qb'] = SignalState.low;
      state['qc'] = SignalState.low;
      state['qd'] = SignalState.low;
      state['prev_cka'] = SignalState.low;

      final result = chip.evaluate(
        {14: SignalState.high},
        internalState: state,
      );

      expect(result[12], SignalState.low);
      expect(result[9], SignalState.low);
      expect(result[8], SignalState.low);
      expect(result[11], SignalState.low);
    });

    test('unknown or highZ clock leaves the outputs unchanged', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['qa'] = SignalState.high;
      state['qb'] = SignalState.low;
      state['qc'] = SignalState.low;
      state['qd'] = SignalState.low;
      state['prev_cka'] = SignalState.high;

      final unknownResult = chip.evaluate(
        {14: SignalState.unknown},
        internalState: state,
      );
      expect(unknownResult[12], SignalState.high);

      final highZResult = chip.evaluate(
        {14: SignalState.highZ},
        internalState: state,
      );
      expect(highZResult[12], SignalState.high);
    });
  });
}
