import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chip_instance.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';
import '../providers/circuit_provider.dart';
import '../engine/simulation_engine.dart';
import '../providers/simulation_provider.dart';
import '../theme/dark_theme.dart';

/// Right panel showing input switches and output LEDs.
class IOPanel extends ConsumerWidget {
  const IOPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circuit = ref.watch(circuitProvider);
    final engine = ref.watch(simulationEngineProvider);

    // Find switches and LEDs among the chips
    final switches =
        circuit.chips.where((c) => c.definition.model == 'INPUT').toList();
    final leds =
        circuit.chips.where((c) => c.definition.model == 'LED').toList();

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          left: BorderSide(color: AppTheme.chipBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.chipBorder, width: 1),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.tune, size: 16, color: AppTheme.textPrimary),
                SizedBox(width: 6),
                Text(
                  'I/O Panel',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Input Switches section
          _SectionHeader(
            title: 'Input Switches',
            onAdd: () => _addSwitch(ref),
          ),
          Expanded(
            flex: 1,
            child: switches.isEmpty
                ? const Center(
                    child: Text(
                      'No switches\nTap + to add',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: switches.length,
                    itemBuilder: (context, index) {
                      return _SwitchWidget(
                        chip: switches[index],
                        engine: engine,
                      );
                    },
                  ),
          ),

          const Divider(color: AppTheme.chipBorder, height: 1),

          // Output LEDs section
          _SectionHeader(
            title: 'Output LEDs',
            onAdd: () => _addLED(ref),
          ),
          Expanded(
            flex: 1,
            child: leds.isEmpty
                ? const Center(
                    child: Text(
                      'No LEDs\nTap + to add',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: leds.length,
                    itemBuilder: (context, index) {
                      return _LEDWidget(chip: leds[index]);
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
    notifier.addChip('INPUT', Offset(120, 140 + count * 100.0));
  }

  void _addLED(WidgetRef ref) {
    final notifier = ref.read(circuitProvider.notifier);
    final count = ref
        .read(circuitProvider)
        .chips
        .where((c) => c.definition.model == 'LED')
        .length;
    notifier.addChip('LED', Offset(720, 140 + count * 100.0));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;

  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
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
              color: AppTheme.accentGreen,
              padding: EdgeInsets.zero,
              tooltip: 'Add $title',
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchWidget extends ConsumerWidget {
  final ChipInstance chip;
  final SimulationEngine engine;

  const _SwitchWidget({required this.chip, required this.engine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A switch drives its output pin; use that pin as the controlled signal.
    final switchPin = chip.pinStates.values.firstWhere(
      (p) => p.direction == PinDirection.output,
      orElse: () => chip.pinStates.values.first,
    );
    final pinId = chip.pinId(switchPin.number);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: AppTheme.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.toggle_on_outlined,
              size: 20,
              color: switchPin.value == SignalState.high
                  ? AppTheme.signalHigh
                  : AppTheme.signalLow,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                chip.id,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
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
                    ? AppTheme.signalHigh
                    : AppTheme.textSecondary,
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

  const _LEDWidget({required this.chip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // An LED observes its input pin.
    final inputPin = chip.pinStates.values.firstWhere(
      (p) => p.direction == PinDirection.input,
      orElse: () => chip.pinStates.values.first,
    );
    final isLit = inputPin.value == SignalState.high;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: AppTheme.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLit ? AppTheme.signalHigh : AppTheme.signalHighZ,
                boxShadow: isLit
                    ? [
                        BoxShadow(
                          color: AppTheme.signalHigh.withValues(alpha: 0.5),
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
                chip.id,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
              ),
            ),
            Text(
              isLit ? 'ON' : 'OFF',
              style: TextStyle(
                color: isLit ? AppTheme.signalHigh : AppTheme.textSecondary,
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
