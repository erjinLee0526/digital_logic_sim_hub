import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  group('SignalState logic operations', () {
    group('NAND', () {
      test('0 NAND 0 = 1', () {
        expect(SignalState.nand(SignalState.low, SignalState.low),
            SignalState.high);
      });
      test('0 NAND 1 = 1', () {
        expect(SignalState.nand(SignalState.low, SignalState.high),
            SignalState.high);
      });
      test('1 NAND 0 = 1', () {
        expect(SignalState.nand(SignalState.high, SignalState.low),
            SignalState.high);
      });
      test('1 NAND 1 = 0', () {
        expect(SignalState.nand(SignalState.high, SignalState.high),
            SignalState.low);
      });
      test('0 NAND X = 1', () {
        expect(SignalState.nand(SignalState.low, SignalState.unknown),
            SignalState.high);
      });
      test('1 NAND X = X', () {
        expect(SignalState.nand(SignalState.high, SignalState.unknown),
            SignalState.unknown);
      });
      test('Z NAND 0 = X', () {
        expect(SignalState.nand(SignalState.highZ, SignalState.low),
            SignalState.unknown);
      });
      test('Z NAND 1 = X', () {
        expect(SignalState.nand(SignalState.highZ, SignalState.high),
            SignalState.unknown);
      });
    });

    group('AND', () {
      test('0 AND 0 = 0', () {
        expect(SignalState.and(SignalState.low, SignalState.low),
            SignalState.low);
      });
      test('1 AND 1 = 1', () {
        expect(SignalState.and(SignalState.high, SignalState.high),
            SignalState.high);
      });
      test('1 AND 0 = 0', () {
        expect(SignalState.and(SignalState.high, SignalState.low),
            SignalState.low);
      });
    });

    group('OR', () {
      test('0 OR 0 = 0', () {
        expect(SignalState.or(SignalState.low, SignalState.low), SignalState.low);
      });
      test('1 OR 0 = 1', () {
        expect(
            SignalState.or(SignalState.high, SignalState.low), SignalState.high);
      });
      test('1 OR 1 = 1', () {
        expect(
            SignalState.or(SignalState.high, SignalState.high), SignalState.high);
      });
    });

    group('NOT', () {
      test('NOT 0 = 1', () {
        expect(SignalState.low.not(), SignalState.high);
      });
      test('NOT 1 = 0', () {
        expect(SignalState.high.not(), SignalState.low);
      });
      test('NOT X = X', () {
        expect(SignalState.unknown.not(), SignalState.unknown);
      });
      test('NOT Z = X', () {
        expect(SignalState.highZ.not(), SignalState.unknown);
      });
    });

    group('XOR', () {
      test('0 XOR 0 = 0', () {
        expect(
            SignalState.xor(SignalState.low, SignalState.low), SignalState.low);
      });
      test('0 XOR 1 = 1', () {
        expect(
            SignalState.xor(SignalState.low, SignalState.high), SignalState.high);
      });
      test('1 XOR 1 = 0', () {
        expect(
            SignalState.xor(SignalState.high, SignalState.high), SignalState.low);
      });
      test('X XOR 0 = X', () {
        expect(SignalState.xor(SignalState.unknown, SignalState.low),
            SignalState.unknown);
      });
    });
  });
}
