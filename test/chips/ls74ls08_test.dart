import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls08.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS08 chip;

  setUp(() {
    chip = Chip74LS08();
  });

  group('Chip74LS08', () {
    test('has correct model number', () {
      expect(chip.model, '74LS08');
    });

    test('has 14 pins with the correct labels and directions', () {
      const expected = {
        1: ('1A', 'input'),
        2: ('1B', 'input'),
        3: ('1Y', 'output'),
        4: ('2A', 'input'),
        5: ('2B', 'input'),
        6: ('2Y', 'output'),
        7: ('GND', 'ground'),
        8: ('3Y', 'output'),
        9: ('3A', 'input'),
        10: ('3B', 'input'),
        11: ('4Y', 'output'),
        12: ('4A', 'input'),
        13: ('4B', 'input'),
        14: ('VCC', 'power'),
      };
      expect(chip.pinDefinitions.length, 14);
      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key} label');
        expect(pin.direction.name, entry.value.$2,
            reason: 'pin ${entry.key} direction');
      }
    });

    test('each AND gate follows the full truth table', () {
      const gates = {
        'Gate 1': (inA: 1, inB: 2, out: 3),
        'Gate 2': (inA: 4, inB: 5, out: 6),
        'Gate 3': (inA: 9, inB: 10, out: 8),
        'Gate 4': (inA: 12, inB: 13, out: 11),
      };
      final cases = <(SignalState, SignalState, SignalState)>[
        (SignalState.low, SignalState.low, SignalState.low),
        (SignalState.low, SignalState.high, SignalState.low),
        (SignalState.high, SignalState.low, SignalState.low),
        (SignalState.high, SignalState.high, SignalState.high),
      ];
      for (final gate in gates.entries) {
        for (final c in cases) {
          final result = chip.evaluate({
            gate.value.inA: c.$1,
            gate.value.inB: c.$2,
          });
          expect(result[gate.value.out], c.$3,
              reason: '${gate.key} (${c.$1.displayName},${c.$2.displayName})');
        }
      }
    });

    test('low input dominates unknown (gives low output)', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.unknown,
      });
      expect(result[3], SignalState.low);
    });

    test('unknown input gives unknown output for non-dominant case', () {
      final result = chip.evaluate({
        1: SignalState.high,
        2: SignalState.unknown,
      });
      expect(result[3], SignalState.unknown);
    });

    test('highZ input gives unknown output even with a dominating input', () {
      final result = chip.evaluate({
        1: SignalState.highZ,
        2: SignalState.low,
      });
      expect(result[3], SignalState.unknown);
    });
  });
}
