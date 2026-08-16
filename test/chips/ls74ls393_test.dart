import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls393.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS393 chip;

  setUp(() {
    chip = Chip74LS393();
  });

  group('Chip74LS393', () {
    test('has correct model and DIP-14 pinout', () {
      expect(chip.model, '74LS393');
      expect(chip.pinDefinitions.length, 14);

      const expected = {
        1: ('1CP', 'input'),
        2: ('1MR', 'input'),
        3: ('1Q0', 'output'),
        4: ('1Q1', 'output'),
        5: ('1Q2', 'output'),
        6: ('1Q3', 'output'),
        7: ('GND', 'ground'),
        8: ('2Q3', 'output'),
        9: ('2Q2', 'output'),
        10: ('2Q1', 'output'),
        11: ('2Q0', 'output'),
        12: ('2MR', 'input'),
        13: ('2CP', 'input'),
        14: ('VCC', 'power'),
      };

      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key} label');
        expect(pin.direction.name, entry.value.$2,
            reason: 'pin ${entry.key} direction');
      }
    });

    test('each section counts falling CP edges independently', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q1$i'] = SignalState.low;
        state['q2$i'] = SignalState.low;
      }
      state['prev_cp1'] = SignalState.high;
      state['prev_cp2'] = SignalState.high;

      var result = chip.evaluate(
        {1: SignalState.low, 13: SignalState.low},
        internalState: state,
      );
      expect(result[3], SignalState.high); // 1Q0
      expect(result[11], SignalState.high); // 2Q0

      chip.evaluate(
        {1: SignalState.high, 13: SignalState.high},
        internalState: state,
      );
      result = chip.evaluate(
        {1: SignalState.low, 13: SignalState.high},
        internalState: state,
      );
      expect(result[3], SignalState.low);
      expect(result[4], SignalState.high); // 1Q1
      expect(result[11], SignalState.high); // counter 2 unchanged
    });

    test('each MR asynchronously clears only its own section', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q1$i'] = SignalState.high;
        state['q2$i'] = SignalState.high;
      }
      state['prev_cp1'] = SignalState.high;
      state['prev_cp2'] = SignalState.high;

      final result = chip.evaluate(
        {1: SignalState.low, 2: SignalState.high},
        internalState: state,
      );

      expect(result[3], SignalState.low);
      expect(result[4], SignalState.low);
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.low);
      expect(result[11], SignalState.high); // counter 2 untouched
    });

    test('wraps from 1111 to 0000', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q1$i'] = SignalState.high;
      }
      state['prev_cp1'] = SignalState.high;

      final result = chip.evaluate(
        {1: SignalState.low},
        internalState: state,
      );

      expect(result[3], SignalState.low);
      expect(result[4], SignalState.low);
      expect(result[5], SignalState.low);
      expect(result[6], SignalState.low);
    });

    test('rising CP edges do not change the count', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q1$i'] = SignalState.low;
      }
      state['prev_cp1'] = SignalState.low;

      final result = chip.evaluate(
        {1: SignalState.high},
        internalState: state,
      );

      expect(result[3], SignalState.low);
      expect(result[4], SignalState.low);
    });

    test('unknown or highZ clock leaves the outputs unchanged', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q1$i'] = SignalState.low;
      }
      state['q10'] = SignalState.high;
      state['prev_cp1'] = SignalState.high;

      final unknownResult = chip.evaluate(
        {1: SignalState.unknown},
        internalState: state,
      );
      expect(unknownResult[3], SignalState.high);

      final highZResult = chip.evaluate(
        {1: SignalState.highZ},
        internalState: state,
      );
      expect(highZResult[3], SignalState.high);
    });
  });
}
