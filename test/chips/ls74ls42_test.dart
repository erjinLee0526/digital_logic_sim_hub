import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls42.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS42 chip;

  setUp(() => chip = Chip74LS42());

  group('Chip74LS42', () {
    test('has correct model number', () {
      expect(chip.model, '74LS42');
    });

    test('has the correct 16-pin layout', () {
      const expected = {
        1: ('Y0', 'output'),
        2: ('Y1', 'output'),
        3: ('Y2', 'output'),
        4: ('Y3', 'output'),
        5: ('Y4', 'output'),
        6: ('Y5', 'output'),
        7: ('Y6', 'output'),
        8: ('GND', 'ground'),
        9: ('Y7', 'output'),
        10: ('Y8', 'output'),
        11: ('Y9', 'output'),
        12: ('A3', 'input'),
        13: ('A2', 'input'),
        14: ('A1', 'input'),
        15: ('A0', 'input'),
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

    test('decodes all 16 input codes correctly', () {
      const outputs = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11];
      for (var code = 0; code < 16; code++) {
        final result = chip.evaluate({
          12: (code & 8) != 0 ? SignalState.high : SignalState.low,
          13: (code & 4) != 0 ? SignalState.high : SignalState.low,
          14: (code & 2) != 0 ? SignalState.high : SignalState.low,
          15: (code & 1) != 0 ? SignalState.high : SignalState.low,
        });
        for (var i = 0; i < outputs.length; i++) {
          final expected = code <= 9 && i == code
              ? SignalState.low
              : SignalState.high;
          expect(result[outputs[i]], expected,
              reason: 'code $code, output $i');
        }
      }
    });

    test('unknown input makes every output unknown', () {
      final result = chip.evaluate({
        12: SignalState.low,
        13: SignalState.low,
        14: SignalState.unknown,
        15: SignalState.low,
      });
      expect(result.values.every((v) => v == SignalState.unknown), isTrue);
    });

    test('highZ input makes every output unknown', () {
      final result = chip.evaluate({
        12: SignalState.low,
        13: SignalState.low,
        14: SignalState.low,
        15: SignalState.highZ,
      });
      expect(result.values.every((v) => v == SignalState.unknown), isTrue);
    });
  });
}
