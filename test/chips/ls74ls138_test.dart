import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls138.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS138 chip;

  setUp(() => chip = Chip74LS138());

  group('Chip74LS138', () {
    test('has correct model number', () {
      expect(chip.model, '74LS138');
    });

    test('has the correct 16-pin layout', () {
      const expected = {
        1: ('A', 'input'),
        2: ('B', 'input'),
        3: ('C', 'input'),
        4: ('~G2A', 'input'),
        5: ('~G2B', 'input'),
        6: ('G1', 'input'),
        7: ('~Y7', 'output'),
        8: ('GND', 'ground'),
        9: ('~Y6', 'output'),
        10: ('~Y5', 'output'),
        11: ('~Y4', 'output'),
        12: ('~Y3', 'output'),
        13: ('~Y2', 'output'),
        14: ('~Y1', 'output'),
        15: ('~Y0', 'output'),
        16: ('VCC', 'power'),
      };
      expect(chip.pinDefinitions.length, 16);
      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key}');
        expect(pin.direction.name, entry.value.$2, reason: 'pin ${entry.key}');
      }
    });

    test('decodes all 8 addresses when enabled', () {
      // Outputs in address order: ~Y0(15) .. ~Y7(7)
      const outputs = [15, 14, 13, 12, 11, 10, 9, 7];
      for (var code = 0; code < 8; code++) {
        final result = chip.evaluate({
          1: (code & 1) != 0 ? SignalState.high : SignalState.low,
          2: (code & 2) != 0 ? SignalState.high : SignalState.low,
          3: (code & 4) != 0 ? SignalState.high : SignalState.low,
          4: SignalState.low,
          5: SignalState.low,
          6: SignalState.high,
        });
        for (var i = 0; i < outputs.length; i++) {
          expect(
            result[outputs[i]],
            i == code ? SignalState.low : SignalState.high,
            reason: 'code $code, output ~Y$i',
          );
        }
      }
    });

    test('all outputs high when any enable condition fails', () {
      const outputs = [15, 14, 13, 12, 11, 10, 9, 7];
      final disabledCases = [
        // G1 low
        {4: SignalState.low, 5: SignalState.low, 6: SignalState.low},
        // ~G2A high
        {4: SignalState.high, 5: SignalState.low, 6: SignalState.high},
        // ~G2B high
        {4: SignalState.low, 5: SignalState.high, 6: SignalState.high},
      ];
      for (final enables in disabledCases) {
        final result = chip.evaluate({
          1: SignalState.low,
          2: SignalState.low,
          3: SignalState.low,
          ...enables,
        });
        for (final pin in outputs) {
          expect(result[pin], SignalState.high);
        }
      }
    });

    test('disabled outputs stay high even with unknown address', () {
      final result = chip.evaluate({
        1: SignalState.unknown,
        2: SignalState.unknown,
        3: SignalState.unknown,
        4: SignalState.low,
        5: SignalState.low,
        6: SignalState.low, // G1 low -> disabled
      });
      expect(result.values.every((v) => v == SignalState.high), isTrue);
    });

    test('unknown enable makes every output unknown', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.low,
        3: SignalState.low,
        4: SignalState.unknown, // ~G2A unknown
        5: SignalState.low,
        6: SignalState.high,
      });
      expect(result.values.every((v) => v == SignalState.unknown), isTrue);
    });

    test('unknown address while enabled makes every output unknown', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.unknown,
        3: SignalState.low,
        4: SignalState.low,
        5: SignalState.low,
        6: SignalState.high,
      });
      expect(result.values.every((v) => v == SignalState.unknown), isTrue);
    });

    test('highZ on any input makes every output unknown', () {
      final result = chip.evaluate({
        1: SignalState.highZ,
        2: SignalState.low,
        3: SignalState.low,
        4: SignalState.low,
        5: SignalState.low,
        6: SignalState.high,
      });
      expect(result.values.every((v) => v == SignalState.unknown), isTrue);
    });
  });
}
