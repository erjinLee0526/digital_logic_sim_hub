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

    group('XNOR', () {
      test('0 XNOR 0 = 1', () {
        expect(SignalState.xnor(SignalState.low, SignalState.low),
            SignalState.high);
      });
      test('0 XNOR 1 = 0', () {
        expect(SignalState.xnor(SignalState.low, SignalState.high),
            SignalState.low);
      });
      test('1 XNOR 0 = 0', () {
        expect(SignalState.xnor(SignalState.high, SignalState.low),
            SignalState.low);
      });
      test('1 XNOR 1 = 1', () {
        expect(SignalState.xnor(SignalState.high, SignalState.high),
            SignalState.high);
      });
      test('X XNOR 0 = X', () {
        expect(SignalState.xnor(SignalState.unknown, SignalState.low),
            SignalState.unknown);
      });
      test('Z XNOR 0 = X', () {
        expect(
            SignalState.xnor(SignalState.highZ, SignalState.low),
            SignalState.unknown);
      });
    });

    group('NOR with highZ', () {
      test('Z NOR 0 = X', () {
        expect(SignalState.nor(SignalState.highZ, SignalState.low),
            SignalState.unknown);
      });
      test('Z NOR 1 = X', () {
        expect(SignalState.nor(SignalState.highZ, SignalState.high),
            SignalState.unknown);
      });
      test('1 NOR X = 0 (dominating input)', () {
        expect(SignalState.nor(SignalState.high, SignalState.unknown),
            SignalState.low);
      });
    });

    group('multi-input gates', () {
      test('NAND3 0 controls to 1, all-1 gives 0', () {
        expect(
            SignalState.nand3(
                SignalState.low, SignalState.high, SignalState.high),
            SignalState.high);
        expect(
            SignalState.nand3(
                SignalState.high, SignalState.high, SignalState.high),
            SignalState.low);
      });
      test('AND3 all-1 gives 1, 0 controls to 0', () {
        expect(
            SignalState.and3(
                SignalState.high, SignalState.high, SignalState.high),
            SignalState.high);
        expect(
            SignalState.and3(
                SignalState.high, SignalState.low, SignalState.high),
            SignalState.low);
      });
      test('NOR3 1 controls to 0, all-0 gives 1', () {
        expect(
            SignalState.nor3(
                SignalState.low, SignalState.low, SignalState.high),
            SignalState.low);
        expect(
            SignalState.nor3(
                SignalState.low, SignalState.low, SignalState.low),
            SignalState.high);
      });
      test('NAND4 all-1 gives 0, any-0 gives 1', () {
        expect(
            SignalState.nand4(SignalState.high, SignalState.high,
                SignalState.high, SignalState.high),
            SignalState.low);
        expect(
            SignalState.nand4(SignalState.high, SignalState.high,
                SignalState.high, SignalState.low),
            SignalState.high);
      });
      test('AND4 all-1 gives 1, any-0 gives 0', () {
        expect(
            SignalState.and4(SignalState.high, SignalState.high,
                SignalState.high, SignalState.high),
            SignalState.high);
        expect(
            SignalState.and4(SignalState.low, SignalState.high,
                SignalState.high, SignalState.high),
            SignalState.low);
      });
      test('highZ input gives unknown even with a controlling input', () {
        expect(
            SignalState.nand3(
                SignalState.highZ, SignalState.low, SignalState.high),
            SignalState.unknown);
        expect(
            SignalState.nand4(SignalState.high, SignalState.high,
                SignalState.high, SignalState.highZ),
            SignalState.unknown);
        expect(
            SignalState.nor3(
                SignalState.highZ, SignalState.high, SignalState.low),
            SignalState.unknown);
      });
      test('unknown input is dominated by a controlling input', () {
        expect(
            SignalState.nand3(
                SignalState.unknown, SignalState.low, SignalState.high),
            SignalState.high);
        expect(
            SignalState.nor3(
                SignalState.unknown, SignalState.high, SignalState.low),
            SignalState.low);
      });
    });
  });
}
