import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls74.dart';
import 'package:digital_logic_sim/models/pin.dart';
import 'package:digital_logic_sim/models/signal_state.dart';

void main() {
  late Chip74LS74 chip;

  setUp(() {
    chip = Chip74LS74();
  });

  group('Chip74LS74', () {
    test('has correct model and DIP-14 pinout', () {
      expect(chip.model, '74LS74');
      expect(chip.pinDefinitions.length, 14);

      Map<int, PinDefinition> pins() =>
          {for (final pin in chip.pinDefinitions) pin.number: pin};

      expect(pins()[1]!.label, '~1CLR');
      expect(pins()[1]!.direction, PinDirection.input);
      expect(pins()[2]!.label, '1D');
      expect(pins()[3]!.label, '1CLK');
      expect(pins()[4]!.label, '~1PRE');
      expect(pins()[5]!.label, '1Q');
      expect(pins()[5]!.direction, PinDirection.output);
      expect(pins()[6]!.label, '~1Q');
      expect(pins()[7]!.direction, PinDirection.ground);
      expect(pins()[14]!.direction, PinDirection.power);
      expect(pins()[9]!.label, '2Q');
      expect(pins()[8]!.label, '~2Q');
    });

    test('initial state remembers unknown previous clocks', () {
      expect(chip.initialState['ff1_prev_clk'], SignalState.unknown);
      expect(chip.initialState['ff2_prev_clk'], SignalState.unknown);
    });

    test('asynchronous preset forces Q high', () {
      final result = chip.evaluate({
        1: SignalState.high, // ~1CLR inactive
        2: SignalState.low, // D
        3: SignalState.low, // CLK
        4: SignalState.low, // ~1PRE active
      });

      expect(result[5], SignalState.high);
      expect(result[6], SignalState.low);
    });

    test('asynchronous clear forces Q low', () {
      final result = chip.evaluate({
        1: SignalState.low, // ~1CLR active
        2: SignalState.high, // D
        3: SignalState.high, // CLK
        4: SignalState.high, // ~1PRE inactive
      });

      expect(result[5], SignalState.low);
      expect(result[6], SignalState.high);
    });

    test('simultaneous preset and clear drives both outputs high', () {
      final result = chip.evaluate({
        1: SignalState.low,
        2: SignalState.low,
        3: SignalState.low,
        4: SignalState.low,
      });

      expect(result[5], SignalState.high);
      expect(result[6], SignalState.high);
    });

    test('rising clock edge latches D', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        1: SignalState.high,
        2: SignalState.high,
        3: SignalState.low,
        4: SignalState.high,
      };

      // No edge yet: hold the current (unknown) output.
      final beforeEdge = chip.evaluate(base, internalState: state);
      expect(beforeEdge[5], SignalState.unknown);
      expect(beforeEdge[6], SignalState.unknown);

      final afterEdge = chip.evaluate(
        {...base, 3: SignalState.high},
        internalState: state,
      );
      expect(afterEdge[5], SignalState.high);
      expect(afterEdge[6], SignalState.low);
    });

    test('changing D while CLK is high does not change Q', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      state['ff1_prev_clk'] = SignalState.high;
      final base = <int, SignalState>{
        1: SignalState.high,
        2: SignalState.high,
        3: SignalState.high,
        4: SignalState.high,
        5: SignalState.high,
        6: SignalState.low,
      };

      final result = chip.evaluate(
        {...base, 2: SignalState.low},
        internalState: state,
      );
      expect(result[5], SignalState.high);
      expect(result[6], SignalState.low);
    });

    test('later rising edge latches the new D value', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final base = <int, SignalState>{
        1: SignalState.high,
        2: SignalState.high,
        3: SignalState.low,
        4: SignalState.high,
        5: SignalState.unknown,
        6: SignalState.unknown,
      };

      chip.evaluate(base, internalState: state);
      final afterFirstEdge = chip.evaluate(
        {...base, 3: SignalState.high},
        internalState: state,
      );
      expect(afterFirstEdge[5], SignalState.high);
      expect(afterFirstEdge[6], SignalState.low);

      final held = chip.evaluate(
        {
          ...base,
          2: SignalState.low,
          3: SignalState.low,
          5: afterFirstEdge[5]!,
          6: afterFirstEdge[6]!,
        },
        internalState: state,
      );
      expect(held[5], SignalState.high);
      expect(held[6], SignalState.low);

      final nextEdge = chip.evaluate(
        {
          ...base,
          2: SignalState.low,
          3: SignalState.high,
          5: afterFirstEdge[5]!,
          6: afterFirstEdge[6]!,
        },
        internalState: state,
      );
      expect(nextEdge[5], SignalState.low);
      expect(nextEdge[6], SignalState.high);
    });

    test('unknown D at a rising edge produces unknown outputs', () {
      final state = Map<String, SignalState>.of(chip.initialState);
      final result = chip.evaluate(
        {
          1: SignalState.high,
          2: SignalState.unknown,
          3: SignalState.high,
          4: SignalState.high,
        },
        internalState: state,
      );

      expect(result[5], SignalState.unknown);
      expect(result[6], SignalState.unknown);
    });
  });
}
