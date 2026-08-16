import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls148.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS148 chip;

  setUp(() => chip = Chip74LS148());

  Map<int, SignalState> allInputsHigh() => {
        for (final pin in const [4, 3, 2, 1, 13, 12, 11, 10])
          pin: SignalState.high,
      };

  group('Chip74LS148', () {
    test('has correct model number', () {
      expect(chip.model, '74LS148');
    });

    test('has the correct 16-pin layout', () {
      const expected = {
        1: ('I4', 'input'),
        2: ('I5', 'input'),
        3: ('I6', 'input'),
        4: ('I7', 'input'),
        5: ('EI', 'input'),
        6: ('A2', 'output'),
        7: ('A1', 'output'),
        8: ('GND', 'ground'),
        9: ('A0', 'output'),
        10: ('I0', 'input'),
        11: ('I1', 'input'),
        12: ('I2', 'input'),
        13: ('I3', 'input'),
        14: ('GS', 'output'),
        15: ('EO', 'output'),
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

    test('EI high disables the chip', () {
      final result = chip.evaluate({5: SignalState.high});
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.high);
      expect(result[9], SignalState.high);
      expect(result[14], SignalState.high);
      expect(result[15], SignalState.high);
    });

    test('encodes each active input in inverted binary', () {
      const inputPins = [4, 3, 2, 1, 13, 12, 11, 10]; // I7..I0
      for (var n = 0; n < 8; n++) {
        final inputs = allInputsHigh();
        inputs[5] = SignalState.low; // EI enabled
        inputs[inputPins[n]] = SignalState.low; // I(n) active
        final result = chip.evaluate(inputs);
        final encoded = n; // A2A1A0 = inverted number of I(7-n)
        expect(result[6], SignalState.fromBool((encoded & 4) != 0),
            reason: 'A2 for I$n');
        expect(result[7], SignalState.fromBool((encoded & 2) != 0),
            reason: 'A1 for I$n');
        expect(result[9], SignalState.fromBool((encoded & 1) != 0),
            reason: 'A0 for I$n');
        expect(result[14], SignalState.low, reason: 'GS for I$n');
        expect(result[15], SignalState.high, reason: 'EO for I$n');
      }
    });

    test('the highest-numbered active input wins', () {
      final inputs = allInputsHigh();
      inputs[5] = SignalState.low;
      inputs[10] = SignalState.low; // I0
      inputs[11] = SignalState.low; // I1
      inputs[1] = SignalState.low; // I4
      inputs[4] = SignalState.low; // I7 -> wins
      final result = chip.evaluate(inputs);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);
      expect(result[9], SignalState.low); // 000 = I7
      expect(result[14], SignalState.low);
      expect(result[15], SignalState.high);
    });

    test('no active input drives EO low for cascading', () {
      final inputs = allInputsHigh();
      inputs[5] = SignalState.low;
      final result = chip.evaluate(inputs);
      expect(result[6], SignalState.high);
      expect(result[7], SignalState.high);
      expect(result[9], SignalState.high);
      expect(result[14], SignalState.high);
      expect(result[15], SignalState.low);
    });

    test('unknown input above the active one makes outputs unknown', () {
      final inputs = allInputsHigh();
      inputs[5] = SignalState.low;
      inputs[3] = SignalState.unknown; // I6 unknown
      inputs[1] = SignalState.low; // I4 active
      final result = chip.evaluate(inputs);
      expect(result[6], SignalState.unknown);
      expect(result[7], SignalState.unknown);
      expect(result[9], SignalState.unknown);
      expect(result[14], SignalState.unknown);
      expect(result[15], SignalState.unknown);
    });

    test('unknown input below the active one is ignored', () {
      final inputs = allInputsHigh();
      inputs[5] = SignalState.low;
      inputs[4] = SignalState.low; // I7 active
      inputs[10] = SignalState.unknown; // I0 irrelevant
      final result = chip.evaluate(inputs);
      expect(result[6], SignalState.low);
      expect(result[7], SignalState.low);
      expect(result[9], SignalState.low); // 000 = I7
      expect(result[14], SignalState.low);
      expect(result[15], SignalState.high);
    });

    test('highZ on any input makes outputs unknown', () {
      final inputs = allInputsHigh();
      inputs[5] = SignalState.low;
      inputs[12] = SignalState.highZ; // I2 floating
      final result = chip.evaluate(inputs);
      for (final pin in const [6, 7, 9, 14, 15]) {
        expect(result[pin], SignalState.unknown, reason: 'pin $pin');
      }
    });

    test('unknown EI makes outputs unknown', () {
      final result = chip.evaluate({5: SignalState.unknown});
      for (final pin in const [6, 7, 9, 14, 15]) {
        expect(result[pin], SignalState.unknown, reason: 'pin $pin');
      }
    });
  });
}
