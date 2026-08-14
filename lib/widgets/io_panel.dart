import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/simulation_engine.dart';
import '../models/chip_instance.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';
import '../providers/circuit_provider.dart';
import '../providers/simulation_provider.dart';
import '../theme/app_theme.dart';
import '../theme/glass.dart';

class _InputControl {
  final ChipInstance chip;
  final PinState pin;
  final String name;

  const _InputControl({
    required this.chip,
    required this.pin,
    required this.name,
  });
}

/// Right panel showing input switches and output LEDs.
class IOPanel extends ConsumerWidget {
  const IOPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final circuit = ref.watch(circuitProvider);
    final engine = ref.watch(simulationEngineProvider);

    // Flatten each dual-input component into IN1/IN2 controls while keeping
    // the same global numbering used by the canvas.
    final inputControls = <_InputControl>[];
    var inputNumber = 1;
    for (final chip in circuit.chips) {
      if (chip.definition.model != 'INPUT') continue;
      final outputPins = chip.pinStates.values
          .where((p) => p.direction == PinDirection.output)
          .toList()
        ..sort((a, b) => a.number.compareTo(b.number));
      for (final pin in outputPins) {
        inputControls.add(_InputControl(
          chip: chip,
          pin: pin,
          name: 'IN${inputNumber++}',
        ));
      }
    }
    final leds =
        circuit.chips.where((c) => c.definition.model == 'LED').toList();

    return GlassPanel(
      width: 220,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: p.chipBorder, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.tune, size: 16, color: p.textPrimary),
                const SizedBox(width: 6),
                Text(
                  '输入 / 输出',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Input Switches section
          _SectionHeader(
            title: '输入开关',
            onAdd: () => _addSwitch(ref),
          ),
          Expanded(
            flex: 1,
            child: inputControls.isEmpty
                ? Center(
                    child: Text(
                      '暂无开关\n点击 + 添加',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: p.textSecondary, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: inputControls.length,
                    itemBuilder: (context, index) {
                      return _SwitchWidget(
                        control: inputControls[index],
                        engine: engine,
                      );
                    },
                  ),
          ),

          Divider(color: p.chipBorder, height: 1),

          // Output LEDs section
          _SectionHeader(
            title: '输出指示灯',
            onAdd: () => _addLED(ref),
          ),
          Expanded(
            flex: 1,
            child: leds.isEmpty
                ? Center(
                    child: Text(
                      '暂无指示灯\n点击 + 添加',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: p.textSecondary, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: leds.length,
                    itemBuilder: (context, index) {
                      return _LEDWidget(
                        chip: leds[index],
                        name: 'LED${index + 1}',
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _addSwitch(WidgetRef ref) {
    final notifier = ref.read(circuitProvider.notifier);
    final count = ref
        .read(circuitProvider)
        .chips
        .where((c) => c.definition.model == 'INPUT')
        .length;
    notifier.addChip('INPUT', Offset(120, 140 + count * 120.0));
  }

  void _addLED(WidgetRef ref) {
    final notifier = ref.read(circuitProvider.notifier);
    final count = ref
        .read(circuitProvider)
        .chips
        .where((c) => c.definition.model == 'LED')
        .length;
    notifier.addChip('LED', Offset(720, 140 + count * 120.0));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;

  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              color: p.accentGreen,
              padding: EdgeInsets.zero,
              tooltip: '添加$title',
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchWidget extends ConsumerWidget {
  final _InputControl control;
  final SimulationEngine engine;

  const _SwitchWidget({required this.control, required this.engine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final switchPin = control.pin;
    final pinId = control.chip.pinId(switchPin.number);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: p.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.toggle_on_outlined,
              size: 20,
              color: switchPin.value == SignalState.high
                  ? p.signalHigh
                  : p.signalLow,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                control.name,
                style: TextStyle(color: p.textPrimary, fontSize: 11),
              ),
            ),
            IconButton(
              onPressed: () {
                final circuit = ref.read(circuitProvider);
                engine.rebuild(circuit);
                final newVal = switchPin.value == SignalState.high
                    ? SignalState.low
                    : SignalState.high;
                engine.injectSignal(pinId, newVal);
                engine.runUntilStable();
                // Force repaint
                ref.read(circuitProvider.notifier).forceUpdate();
              },
              icon: Icon(
                switchPin.value == SignalState.high
                    ? Icons.toggle_on
                    : Icons.toggle_off,
                size: 28,
                color: switchPin.value == SignalState.high
                    ? p.signalHigh
                    : p.textSecondary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LEDWidget extends ConsumerWidget {
  final ChipInstance chip;
  final String name;

  const _LEDWidget({required this.chip, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    // An LED observes its input pin.
    final inputPin = chip.pinStates.values.firstWhere(
      (p) => p.direction == PinDirection.input,
      orElse: () => chip.pinStates.values.first,
    );
    final isLit = inputPin.value == SignalState.high;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: p.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLit ? p.signalHigh : p.signalHighZ,
                boxShadow: isLit
                    ? [
                        BoxShadow(
                          color: p.signalHigh.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(color: p.textPrimary, fontSize: 11),
              ),
            ),
            Text(
              isLit ? '亮' : '灭',
              style: TextStyle(
                color: isLit ? p.signalHigh : p.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
