import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/circuit.dart';
import '../models/pin.dart';
import '../providers/circuit_provider.dart';
import '../providers/editor_provider.dart';
import '../providers/simulation_provider.dart';
import '../theme/app_theme.dart';

/// Bottom status bar showing circuit info.
class CircuitStatusBar extends ConsumerWidget {
  const CircuitStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final circuit = ref.watch(circuitProvider);
    final tool = ref.watch(editorToolProvider);
    final selectedPin = ref.watch(selectedPinProvider);
    final selectedChip = ref.watch(selectedChipProvider);
    final selectedWire = ref.watch(selectedWireProvider);
    final engine = ref.watch(simulationEngineProvider);

    String selectionInfo = '无';
    if (selectedPin != null) {
      selectionInfo = _describePin(selectedPin, circuit);
    } else if (selectedChip != null) {
      final chip = circuit.chipById(selectedChip);
      if (chip != null) {
        selectionInfo = '元件：${chip.definition.model}（$selectedChip）';
      } else {
        selectionInfo = '元件：$selectedChip';
      }
    } else if (selectedWire != null) {
      selectionInfo = '导线：$selectedWire';
    }

    final toolName = switch (tool) {
      EditorTool.wiring => '连线',
      EditorTool.dragging => '移动',
      EditorTool.deleting => '删除',
    };

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Selection info
          Text(
            selectionInfo,
            style: TextStyle(color: p.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 16),
          // Tool
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: p.surfaceLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '工具：$toolName',
              style: TextStyle(color: p.accent, fontSize: 10),
            ),
          ),
          const Spacer(),
          // Circuit stats
          Text(
            '元件：${circuit.chips.length}  |  导线：${circuit.wires.length}',
            style: TextStyle(color: p.textSecondary, fontSize: 11),
          ),
          const SizedBox(width: 16),
          // Simulation time
          Text(
            '仿真：${engine.currentTimePs}ps',
            style: TextStyle(color: p.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// Renders a friendly description of a pin for the status bar,
  /// e.g. `74LS00 引脚 3（1Y，输出）`.
  String _describePin(String pinId, Circuit circuit) {
    for (final chip in circuit.chips) {
      final prefix = '${chip.id}_';
      if (!pinId.startsWith(prefix)) continue;

      final number = int.tryParse(pinId.substring(prefix.length));
      final pin = number == null ? null : chip.pinStates[number];
      if (pin == null) return '引脚：$pinId';

      final direction = switch (pin.direction) {
        PinDirection.input => '输入',
        PinDirection.output => '输出',
        PinDirection.power => '电源',
        PinDirection.ground => '接地',
      };
      return '${chip.definition.model} 引脚 $number'
          '（${pin.label}，$direction）';
    }
    return '引脚：$pinId';
  }
}
