import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/circuit_provider.dart';
import '../providers/editor_provider.dart';
import '../providers/simulation_provider.dart';
import '../models/circuit.dart';
import '../models/pin.dart';
import '../engine/simulation_engine.dart';
import '../theme/dark_theme.dart';

/// Bottom status bar showing circuit info.
class CircuitStatusBar extends ConsumerWidget {
  const CircuitStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circuit = ref.watch(circuitProvider);
    final tool = ref.watch(editorToolProvider);
    final selectedPin = ref.watch(selectedPinProvider);
    final selectedChip = ref.watch(selectedChipProvider);
    final selectedWire = ref.watch(selectedWireProvider);
    final engine = ref.watch(simulationEngineProvider);

    String selectionInfo = 'None';
    if (selectedPin != null) {
      selectionInfo = _describePin(selectedPin, circuit);
    } else if (selectedChip != null) {
      final chip = circuit.chipById(selectedChip);
      if (chip != null) {
        selectionInfo = 'Chip: ${chip.definition.model} ($selectedChip)';
      } else {
        selectionInfo = 'Chip: $selectedChip';
      }
    } else if (selectedWire != null) {
      selectionInfo = 'Wire: $selectedWire';
    }

    final toolName = switch (tool) {
      EditorTool.wiring => 'Wiring',
      EditorTool.dragging => 'Moving',
      EditorTool.deleting => 'Deleting',
    };

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.chipBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Selection info
          Text(
            selectionInfo,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 16),
          // Tool
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Tool: $toolName',
              style: const TextStyle(
                  color: AppTheme.accent, fontSize: 10),
            ),
          ),
          const Spacer(),
          // Circuit stats
          Text(
            'Chips: ${circuit.chips.length}  |  Wires: ${circuit.wires.length}',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 16),
          // Simulation time
          Text(
            'Sim: ${engine.currentTimePs}ps',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// Renders a friendly description of a pin for the status bar,
  /// e.g. `74LS00 · pin 3 · 1Y (output)`.
  String _describePin(String pinId, Circuit circuit) {
    for (final chip in circuit.chips) {
      final prefix = '${chip.id}_';
      if (!pinId.startsWith(prefix)) continue;

      final number = int.tryParse(pinId.substring(prefix.length));
      final pin = number == null ? null : chip.pinStates[number];
      if (pin == null) return 'Pin: $pinId';

      final direction = switch (pin.direction) {
        PinDirection.input => 'input',
        PinDirection.output => 'output',
        PinDirection.power => 'power',
        PinDirection.ground => 'ground',
      };
      return '${chip.definition.model} · pin $number · '
          '${pin.label} ($direction)';
    }
    return 'Pin: $pinId';
  }
}
