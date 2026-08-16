import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls93.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS93 chip;

  setUp(() {
    chip = Chip74LS93();
  });

  group('Chip74LS93', () {
    test('has correct model and DIP-14 pinout (NC pins unmodeled)', () {
      expect(chip.model, '74LS93');
      expect(chip.pinDefinitions.length, 10);

      const expected = {
        1: ('CKB', 'input'),
        2: ('R0(1)', 'input'),
        3: ('R0(2)', 'input'),
        5: ('VCC', 'power'),
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

      for (final nc in [4, 6, 7, 13]) {
        expect(chip.pinDefinitions.any((p) => p.number == nc), isFalse,
            reason: 'NC pin $nc should not be modeled');
      }
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

    test('falling CKB advances QB/QC/QD through 0-7 then wraps', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['qa'] = SignalState.low;
      state['qb'] = SignalState.low;
      state['qc'] = SignalState.low;
      state['qd'] = SignalState.low;
      state['prev_ckb'] = SignalState.high;

      const expectedStates = [
        (SignalState.high, SignalState.low, SignalState.low),
        (SignalState.low, SignalState.high, SignalState.low),
        (SignalState.high, SignalState.high, SignalState.low),
        (SignalState.low, SignalState.low, SignalState.high),
        (SignalState.high, SignalState.low, SignalState.high),
        (SignalState.low, SignalState.high, SignalState.high),
        (SignalState.high, SignalState.high, SignalState.high),
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

    test('reset takes priority over a clock edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['qa'] = SignalState.high;
      state['qb'] = SignalState.low;
      state['qc'] = SignalState.low;
      state['qd'] = SignalState.low;
      state['prev_cka'] = SignalState.high;

      final result = chip.evaluate(
        {
          2: SignalState.high,
          3: SignalState.high,
          14: SignalState.low,
        },
        internalState: state,
      );

      expect(result[12], SignalState.low);
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
