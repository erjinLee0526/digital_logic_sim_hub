import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls139.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS139 chip;

  setUp(() => chip = Chip74LS139());

  group('Chip74LS139', () {
    test('has correct model number', () {
      expect(chip.model, '74LS139');
    });

    test('has the correct 16-pin layout', () {
      const expected = {
        1: ('~1G', 'input'),
        2: ('1A', 'input'),
        3: ('1B', 'input'),
        4: ('~1Y0', 'output'),
        5: ('~1Y1', 'output'),
        6: ('~1Y2', 'output'),
        7: ('~1Y3', 'output'),
        8: ('GND', 'ground'),
        9: ('~2Y3', 'output'),
        10: ('~2Y2', 'output'),
        11: ('~2Y1', 'output'),
        12: ('~2Y0', 'output'),
        13: ('2B', 'input'),
        14: ('2A', 'input'),
        15: ('~2G', 'input'),
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

    test('decoder 1 decodes all 4 addresses when enabled', () {
      const outputs = [4, 5, 6, 7]; // ~1Y0 .. ~1Y3
      for (var code = 0; code < 4; code++) {
        final result = chip.evaluate({
          1: SignalState.low, // ~1G
          2: (code & 1) != 0 ? SignalState.high : SignalState.low, // 1A
          3: (code & 2) != 0 ? SignalState.high : SignalState.low, // 1B
        });
        for (var i = 0; i < outputs.length; i++) {
          expect(
            result[outputs[i]],
            i == code ? SignalState.low : SignalState.high,
            reason: 'code $code, output ~1Y$i',
          );
        }
      }
    });

    test('decoder 2 decodes all 4 addresses when enabled', () {
      const outputs = [12, 11, 10, 9]; // ~2Y0 .. ~2Y3
      for (var code = 0; code < 4; code++) {
        final result = chip.evaluate({
          15: SignalState.low, // ~2G
          14: (code & 1) != 0 ? SignalState.high : SignalState.low, // 2A
          13: (code & 2) != 0 ? SignalState.high : SignalState.low, // 2B
        });
        for (var i = 0; i < outputs.length; i++) {
          expect(
            result[outputs[i]],
            i == code ? SignalState.low : SignalState.high,
            reason: 'code $code, output ~2Y$i',
          );
        }
      }
    });

    test('the two halves decode independently', () {
      final result = chip.evaluate({
        1: SignalState.low, // ~1G enabled
        2: SignalState.high, // 1A
        3: SignalState.low, // 1B -> select ~1Y1
        15: SignalState.low, // ~2G enabled
        14: SignalState.low, // 2A
        13: SignalState.high, // 2B -> select ~2Y2
      });
      expect(result[4], SignalState.high);
      expect(result[5], SignalState.low); // ~1Y1
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.high);
      expect(result[12], SignalState.high);
      expect(result[11], SignalState.high);
      expect(result[10], SignalState.low); // ~2Y2
      expect(result[9], SignalState.high);
    });

    test('disabled half outputs all high without affecting the other', () {
      final result = chip.evaluate({
        1: SignalState.high, // ~1G disabled
        2: SignalState.low,
        3: SignalState.low,
        15: SignalState.low, // ~2G enabled
        14: SignalState.high, // 2A
        13: SignalState.high, // 2B -> select ~2Y3
      });
      for (final pin in const [4, 5, 6, 7]) {
        expect(result[pin], SignalState.high, reason: 'pin $pin');
      }
      expect(result[12], SignalState.high);
      expect(result[11], SignalState.high);
      expect(result[10], SignalState.high);
      expect(result[9], SignalState.low);
    });

    test('unknown enable makes only that half unknown', () {
      final result = chip.evaluate({
        1: SignalState.unknown, // ~1G unknown
        2: SignalState.low,
        3: SignalState.low,
        15: SignalState.low, // ~2G enabled
        14: SignalState.low,
        13: SignalState.low, // ~2Y0 selected
      });
      for (final pin in const [4, 5, 6, 7]) {
        expect(result[pin], SignalState.unknown, reason: 'pin $pin');
      }
      expect(result[12], SignalState.low);
      expect(result[11], SignalState.high);
      expect(result[10], SignalState.high);
      expect(result[9], SignalState.high);
    });

    test('unknown address while enabled makes that half unknown', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.unknown, // 1A
        3: SignalState.low,
      });
      for (final pin in const [4, 5, 6, 7]) {
        expect(result[pin], SignalState.unknown, reason: 'pin $pin');
      }
    });

    test('highZ on any input makes that half unknown', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.low,
        3: SignalState.highZ, // 1B floating
        15: SignalState.highZ, // ~2G floating
        14: SignalState.low,
        13: SignalState.low,
      });
      for (final pin in const [4, 5, 6, 7, 12, 11, 10, 9]) {
        expect(result[pin], SignalState.unknown, reason: 'pin $pin');
      }
    });
  });
}
