import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls02.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS02 chip;

  setUp(() {
    chip = Chip74LS02();
  });

  group('Chip74LS02', () {
    test('has correct model number', () {
      expect(chip.model, '74LS02');
    });

    test('has 14 pins with the correct labels and directions', () {
      const expected = {
        1: ('1Y', 'output'),
        2: ('1A', 'input'),
        3: ('1B', 'input'),
        4: ('2Y', 'output'),
        5: ('2A', 'input'),
        6: ('2B', 'input'),
        7: ('GND', 'ground'),
        8: ('3A', 'input'),
        9: ('3B', 'input'),
        10: ('3Y', 'output'),
        11: ('4A', 'input'),
        12: ('4B', 'input'),
        13: ('4Y', 'output'),
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

    test('each NOR gate follows the full truth table', () {
      const gates = {
        'Gate 1': (inA: 2, inB: 3, out: 1),
        'Gate 2': (inA: 5, inB: 6, out: 4),
        'Gate 3': (inA: 8, inB: 9, out: 10),
        'Gate 4': (inA: 11, inB: 12, out: 13),
      };
      final cases = <(SignalState, SignalState, SignalState)>[
        (SignalState.low, SignalState.low, SignalState.high),
        (SignalState.low, SignalState.high, SignalState.low),
        (SignalState.high, SignalState.low, SignalState.low),
        (SignalState.high, SignalState.high, SignalState.low),
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

    test('high input dominates unknown (gives low output)', () {
      final result = chip.evaluate({
        2: SignalState.high,
        3: SignalState.unknown,
      });
      expect(result[1], SignalState.low);
    });

    test('unknown input gives unknown output for non-dominant case', () {
      final result = chip.evaluate({
        2: SignalState.low,
        3: SignalState.unknown,
      });
      expect(result[1], SignalState.unknown);
    });

    test('highZ input gives unknown output even with a dominating input', () {
      final result = chip.evaluate({
        2: SignalState.highZ,
        3: SignalState.high,
      });
      expect(result[1], SignalState.unknown);
    });
  });
}
