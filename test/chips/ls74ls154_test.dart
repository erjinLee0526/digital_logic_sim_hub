import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls154.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS154 chip;

  setUp(() => chip = Chip74LS154());

  group('Chip74LS154', () {
    test('has correct model number', () {
      expect(chip.model, '74LS154');
    });

    test('has the correct 24-pin layout', () {
      const expected = {
        1: ('Y0', 'output'),
        2: ('Y1', 'output'),
        3: ('Y2', 'output'),
        4: ('Y3', 'output'),
        5: ('Y4', 'output'),
        6: ('Y5', 'output'),
        7: ('Y6', 'output'),
        8: ('Y7', 'output'),
        9: ('Y8', 'output'),
        10: ('Y9', 'output'),
        11: ('Y10', 'output'),
        12: ('GND', 'ground'),
        13: ('Y11', 'output'),
        14: ('Y12', 'output'),
        15: ('Y13', 'output'),
        16: ('Y14', 'output'),
        17: ('Y15', 'output'),
        18: ('~G1', 'input'),
        19: ('~G2', 'input'),
        20: ('D', 'input'),
        21: ('C', 'input'),
        22: ('B', 'input'),
        23: ('A', 'input'),
        24: ('VCC', 'power'),
      };
      expect(chip.pinDefinitions.length, 24);
      for (final entry in expected.entries) {
        final pin =
            chip.pinDefinitions.firstWhere((p) => p.number == entry.key);
        expect(pin.label, entry.value.$1, reason: 'pin ${entry.key}');
        expect(pin.direction.name, entry.value.$2, reason: 'pin ${entry.key}');
      }
    });

    test('decodes all 16 addresses when enabled', () {
      const outputs = [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17,
      ];
      for (var code = 0; code < 16; code++) {
        final result = chip.evaluate({
          18: SignalState.low,
          19: SignalState.low,
          23: (code & 1) != 0 ? SignalState.high : SignalState.low, // A
          22: (code & 2) != 0 ? SignalState.high : SignalState.low, // B
          21: (code & 4) != 0 ? SignalState.high : SignalState.low, // C
          20: (code & 8) != 0 ? SignalState.high : SignalState.low, // D
        });
        for (var i = 0; i < outputs.length; i++) {
          expect(
            result[outputs[i]],
            i == code ? SignalState.low : SignalState.high,
            reason: 'code $code, output Y$i',
          );
        }
      }
    });

    test('either enable high makes all outputs high', () {
      for (final g1 in [SignalState.high, SignalState.low]) {
        final result = chip.evaluate({
          18: g1,
          19: g1 == SignalState.high ? SignalState.low : SignalState.high,
          23: SignalState.low,
          22: SignalState.low,
          21: SignalState.low,
          20: SignalState.low,
        });
        expect(result.values.every((v) => v == SignalState.high), isTrue,
            reason: 'G1=$g1');
      }
    });

    test('disabled outputs stay high even with unknown address', () {
      final result = chip.evaluate({
        18: SignalState.high, // disabled
        19: SignalState.low,
        23: SignalState.unknown,
        22: SignalState.unknown,
        21: SignalState.unknown,
        20: SignalState.unknown,
      });
      expect(result.values.every((v) => v == SignalState.high), isTrue);
    });

    test('unknown enable makes every output unknown', () {
      final result = chip.evaluate({
        18: SignalState.unknown,
        19: SignalState.low,
        23: SignalState.low,
        22: SignalState.low,
        21: SignalState.low,
        20: SignalState.low,
      });
      expect(result.values.every((v) => v == SignalState.unknown), isTrue);
    });

    test('unknown address while enabled makes every output unknown', () {
      final result = chip.evaluate({
        18: SignalState.low,
        19: SignalState.low,
        23: SignalState.unknown, // A
        22: SignalState.low,
        21: SignalState.low,
        20: SignalState.low,
      });
      expect(result.values.every((v) => v == SignalState.unknown), isTrue);
    });

    test('highZ on any input makes every output unknown', () {
      final result = chip.evaluate({
        18: SignalState.low,
        19: SignalState.low,
        23: SignalState.low,
        22: SignalState.highZ, // B floating
        21: SignalState.low,
        20: SignalState.low,
      });
      expect(result.values.every((v) => v == SignalState.unknown), isTrue);
    });
  });
}
