import 'chip_definition.dart';
import 'signal_state.dart';

/// One row of an enumerated truth table: driven input levels and the
/// resulting output levels.
class TruthTableRow {
  final List<SignalState> inputs;
  final List<SignalState> outputs;

  const TruthTableRow({required this.inputs, required this.outputs});
}

/// Enumerates every driven (0/1) input combination for [group] and evaluates
/// the outputs through [chip]'s own `evaluate()`, so the displayed datasheet
/// always matches the simulated behavior.
///
/// Input combinations are listed in standard truth-table order: the first
/// input column changes slowest (all 0s first, all 1s last).
List<TruthTableRow> generateTruthTable(
  ChipDefinition chip,
  TruthTableGroup group,
) {
  final inputCount = group.inputPins.length;
  assert(inputCount >= 1, 'A truth table group needs at least one input');
  assert(inputCount <= 10, 'Truth tables support at most 10 inputs per group');

  final rows = <TruthTableRow>[];
  for (var mask = 0; mask < (1 << inputCount); mask++) {
    final inputStates = <int, SignalState>{};
    final inputs = <SignalState>[];
    for (var i = 0; i < inputCount; i++) {
      final isHigh = (mask >> (inputCount - 1 - i)) & 1 == 1;
      final value = isHigh ? SignalState.high : SignalState.low;
      inputStates[group.inputPins[i]] = value;
      inputs.add(value);
    }

    final result = chip.evaluate(inputStates);
    rows.add(TruthTableRow(
      inputs: inputs,
      outputs: [
        for (final pin in group.outputPins)
          result[pin] ?? SignalState.unknown,
      ],
    ));
  }
  return rows;
}
