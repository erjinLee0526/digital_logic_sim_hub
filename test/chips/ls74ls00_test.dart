import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls00.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS00 chip;

  setUp(() {
    chip = Chip74LS00();
  });

  group('Chip74LS00', () {
    test('has correct model number', () {
      expect(chip.model, '74LS00');
    });

    test('has 14 pins', () {
      expect(chip.pinDefinitions.length, 14);
    });

    test('pin layout is correct', () {
      // Verify key pins
      final pin1 = chip.pinDefinitions.firstWhere((p) => p.number == 1);
      expect(pin1.label, '1A');
      expect(pin1.direction.name, 'input');

      final pin3 = chip.pinDefinitions.firstWhere((p) => p.number == 3);
      expect(pin3.label, '1Y');
      expect(pin3.direction.name, 'output');

      final pin7 = chip.pinDefinitions.firstWhere((p) => p.number == 7);
      expect(pin7.label, 'GND');
      expect(pin7.direction.name, 'ground');

      final pin14 = chip.pinDefinitions.firstWhere((p) => p.number == 14);
      expect(pin14.label, 'VCC');
      expect(pin14.direction.name, 'power');
    });

    group('Gate 1 (1A+1B → 1Y)', () {
      test('(0,0) → 1', () {
        final result = chip.evaluate({
          1: SignalState.low,
          2: SignalState.low,
        });
        expect(result[3], SignalState.high);
      });

      test('(0,1) → 1', () {
        final result = chip.evaluate({
          1: SignalState.low,
          2: SignalState.high,
        });
        expect(result[3], SignalState.high);
      });

      test('(1,0) → 1', () {
        final result = chip.evaluate({
          1: SignalState.high,
          2: SignalState.low,
        });
        expect(result[3], SignalState.high);
      });

      test('(1,1) → 0', () {
        final result = chip.evaluate({
          1: SignalState.high,
          2: SignalState.high,
        });
        expect(result[3], SignalState.low);
      });
    });

    group('Gate 2 (2A+2B → 2Y)', () {
      test('(0,0) → 1', () {
        final result = chip.evaluate({
          4: SignalState.low,
          5: SignalState.low,
        });
        expect(result[6], SignalState.high);
      });

      test('(1,1) → 0', () {
        final result = chip.evaluate({
          4: SignalState.high,
          5: SignalState.high,
        });
        expect(result[6], SignalState.low);
      });
    });

    group('Gate 3 (3A+3B → 3Y)', () {
      test('(0,0) → 1', () {
        final result = chip.evaluate({
          9: SignalState.low,
          10: SignalState.low,
        });
        expect(result[8], SignalState.high);
      });

      test('(1,1) → 0', () {
        final result = chip.evaluate({
          9: SignalState.high,
          10: SignalState.high,
        });
        expect(result[8], SignalState.low);
      });
    });

    group('Gate 4 (4A+4B → 4Y)', () {
      test('(0,0) → 1', () {
        final result = chip.evaluate({
          12: SignalState.low,
          13: SignalState.low,
        });
        expect(result[11], SignalState.high);
      });

      test('(1,1) → 0', () {
        final result = chip.evaluate({
          12: SignalState.high,
          13: SignalState.high,
        });
        expect(result[11], SignalState.low);
      });
    });

    test('unknown input gives unknown output for non-dominant case', () {
      final result = chip.evaluate({
        1: SignalState.high,
        2: SignalState.unknown,
      });
      expect(result[3], SignalState.unknown);
    });

    test('zero input dominates unknown (gives high output)', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.unknown,
      });
      expect(result[3], SignalState.high);
    });
  });
}
