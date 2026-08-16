import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls95.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS95 chip;

  setUp(() {
    chip = Chip74LS95();
  });

  group('Chip74LS95', () {
    test('has correct model and DIP-14 pinout', () {
      expect(chip.model, '74LS95');
      expect(chip.pinDefinitions.length, 14);

      const expected = {
        1: ('DS', 'input'),
        2: ('P0', 'input'),
        3: ('P1', 'input'),
        4: ('P2', 'input'),
        5: ('P3', 'input'),
        6: ('S', 'input'),
        7: ('GND', 'ground'),
        8: ('CP2', 'input'),
        9: ('CP1', 'input'),
        10: ('Q3', 'output'),
        11: ('Q2', 'output'),
        12: ('Q1', 'output'),
        13: ('Q0', 'output'),
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

    test('S low shifts right on a falling CP1 edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.low;
      state['q1'] = SignalState.low;
      state['q2'] = SignalState.high;
      state['q3'] = SignalState.low;
      state['prev_cp1'] = SignalState.high;
      state['prev_cp2'] = SignalState.low;

      final result = chip.evaluate(
        {
          6: SignalState.low, // serial mode
          9: SignalState.low, // CP1 falling edge
          8: SignalState.high, // CP2 idle high
          1: SignalState.high, // DS
        },
        internalState: state,
      );

      expect(result[13], SignalState.high); // DS enters Q0
      expect(result[12], SignalState.low); // old Q0
      expect(result[11], SignalState.low); // old Q1
      expect(result[10], SignalState.high); // old Q2
    });

    test('S high loads P0-P3 in parallel on a falling CP2 edge', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_cp1'] = SignalState.high;
      state['prev_cp2'] = SignalState.high;

      final result = chip.evaluate(
        {
          6: SignalState.high, // parallel mode
          9: SignalState.high, // CP1 idle high
          8: SignalState.low, // CP2 falling edge
          2: SignalState.high, // P0
          3: SignalState.low, // P1
          4: SignalState.high, // P2
          5: SignalState.low, // P3
        },
        internalState: state,
      );

      expect(result[13], SignalState.high);
      expect(result[12], SignalState.low);
      expect(result[11], SignalState.high);
      expect(result[10], SignalState.low);
    });

    test('mode control selects which clock is active', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.low;
      }
      state['prev_cp1'] = SignalState.high;
      state['prev_cp2'] = SignalState.high;

      // S low: CP2 falling edge must do nothing.
      var result = chip.evaluate(
        {
          6: SignalState.low,
          9: SignalState.high,
          8: SignalState.low,
          2: SignalState.high,
          3: SignalState.high,
          4: SignalState.high,
          5: SignalState.high,
        },
        internalState: state,
      );
      expect(result[13], SignalState.low);

      // S high: CP1 falling edge must do nothing.
      state['prev_cp1'] = SignalState.high;
      result = chip.evaluate(
        {
          6: SignalState.high,
          9: SignalState.low,
          8: SignalState.high,
          1: SignalState.high,
        },
        internalState: state,
      );
      expect(result[13], SignalState.low);
    });

    test('rising clock edges and no-edge steady levels do not transfer', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['q0'] = SignalState.high;
      state['prev_cp1'] = SignalState.low; // rising edge next
      state['prev_cp2'] = SignalState.high;

      final result = chip.evaluate(
        {
          6: SignalState.low,
          9: SignalState.high, // rising CP1: not a falling edge
          8: SignalState.high,
          1: SignalState.low,
        },
        internalState: state,
      );

      expect(result[13], SignalState.high, reason: 'held');
    });

    test('unknown or highZ DS shifts in unknown', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      for (var i = 0; i < 4; i++) {
        state['q$i'] = SignalState.low;
      }
      state['prev_cp1'] = SignalState.high;
      state['prev_cp2'] = SignalState.low;

      final result = chip.evaluate(
        {
          6: SignalState.low,
          9: SignalState.low,
          8: SignalState.high,
          1: SignalState.highZ,
        },
        internalState: state,
      );

      expect(result[13], SignalState.unknown);
      expect(result[12], SignalState.low);
    });

    test('unknown or highZ parallel data loads unknown', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['prev_cp1'] = SignalState.high;
      state['prev_cp2'] = SignalState.high;

      final result = chip.evaluate(
        {
          6: SignalState.high,
          9: SignalState.high,
          8: SignalState.low,
          2: SignalState.unknown,
          3: SignalState.highZ,
          4: SignalState.high,
          5: SignalState.low,
        },
        internalState: state,
      );

      expect(result[13], SignalState.unknown);
      expect(result[12], SignalState.unknown);
      expect(result[11], SignalState.high);
      expect(result[10], SignalState.low);
    });

    test('power-up state is unknown until a transfer occurs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          6: SignalState.low,
          9: SignalState.low,
          8: SignalState.low,
          1: SignalState.low,
        },
        internalState: state,
      );

      expect(result[13], SignalState.unknown);
      expect(result[12], SignalState.unknown);
      expect(result[11], SignalState.unknown);
      expect(result[10], SignalState.unknown);
    });
  });
}
