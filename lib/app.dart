import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'canvas/circuit_canvas.dart';
import 'engine/simulation_engine.dart';
import 'providers/circuit_provider.dart';
import 'providers/editor_provider.dart';
import 'providers/simulation_provider.dart';
import 'services/file_service.dart';
import 'theme/dark_theme.dart';
import 'widgets/chip_library_panel.dart';
import 'widgets/io_panel.dart';
import 'widgets/status_bar.dart';
import 'widgets/toolbar.dart';

class DigitalLogicSimApp extends StatelessWidget {
  const DigitalLogicSimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Logic Simulator',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const CircuitEditorScreen(),
    );
  }
}

/// The main screen hosting the circuit editor.
class CircuitEditorScreen extends ConsumerStatefulWidget {
  const CircuitEditorScreen({super.key});

  @override
  ConsumerState<CircuitEditorScreen> createState() =>
      _CircuitEditorScreenState();
}

class _CircuitEditorScreenState extends ConsumerState<CircuitEditorScreen> {
  final _filenameController = TextEditingController(text: 'Untitled');

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // Left: Chip Library
          const ChipLibraryPanel(),

          // Center: Canvas with floating toolbar
          Expanded(
            child: Stack(
              children: [
                // Circuit canvas
                const CircuitCanvas(),

                // Floating toolbar (top-left)
                Positioned(
                  top: 12,
                  left: 12,
                  child: const CircuitToolbar(),
                ),

                // Simulation controls (top-center)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _SimulationControls(),
                  ),
                ),
              ],
            ),
          ),

          // Right: I/O Panel
          const IOPanel(),
        ],
      ),
      bottomNavigationBar: const CircuitStatusBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.memory, size: 20, color: AppTheme.accent),
          const SizedBox(width: 8),
          const Text(
            'LogicSim',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 16),
          // Editable filename
          SizedBox(
            width: 160,
            child: TextField(
              controller: _filenameController,
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                isDense: true,
                border: InputBorder.none,
              ),
              onChanged: (_) {},
            ),
          ),
        ],
      ),
      actions: [
        // New circuit
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          tooltip: 'New Circuit',
          onPressed: () {
            ref.read(circuitProvider.notifier).newCircuit();
            _filenameController.text = 'Untitled';
          },
        ),
        // Save
        IconButton(
          icon: const Icon(Icons.save_outlined, size: 20),
          tooltip: 'Save Circuit',
          onPressed: () => _saveCircuit(),
        ),
        // Load
        IconButton(
          icon: const Icon(Icons.folder_open, size: 20),
          tooltip: 'Load Circuit',
          onPressed: () => _loadCircuit(),
        ),
        const SizedBox(width: 8),
        // Reset simulation
        IconButton(
          icon: const Icon(Icons.restart_alt, size: 20),
          tooltip: 'Reset Simulation',
          onPressed: () {
            final engine = ref.read(simulationEngineProvider);
            engine.resetSignals();
            ref.read(circuitProvider.notifier).forceUpdate();
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Future<void> _saveCircuit() async {
    try {
      final name = _filenameController.text.trim();
      if (name.isEmpty) {
        _showSnackBar('Please enter a filename');
        return;
      }
      await FileService.save(ref.read(circuitProvider), name);
      if (mounted) {
        _showSnackBar('Saved: $name');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Save failed: $e');
      }
    }
  }

  Future<void> _loadCircuit() async {
    try {
      final files = await FileService.listSavedCircuits();
      if (!mounted) return;

      if (files.isEmpty) {
        _showSnackBar('No saved circuits found');
        return;
      }

      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => _LoadDialog(files: files),
      );

      if (selected != null && mounted) {
        final circuit = await FileService.load(selected);
        ref.read(circuitProvider.notifier).loadCircuit(circuit);
        _filenameController.text = selected;
        _showSnackBar('Loaded: $selected');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Load failed: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.surfaceLight,
      ),
    );
  }
}

/// Simulation controls (run, pause, step).
class _SimulationControls extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(simulationEngineProvider);
    final circuit = ref.watch(circuitProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.chipBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step
          _buildSmallButton(
            icon: Icons.skip_next,
            tooltip: 'Step one event',
            onTap: () {
              engine.rebuild(circuit);
              engine.step();
              ref.read(circuitProvider.notifier).forceUpdate();
            },
          ),
          const SizedBox(width: 4),
          // Run/Pause
          _buildSmallButton(
            icon: Icons.play_arrow,
            tooltip: 'Run simulation',
            onTap: () {
              engine.rebuild(circuit);
              engine.runUntilStable();
              ref.read(circuitProvider.notifier).forceUpdate();
            },
          ),
          const SizedBox(width: 8),
          Text(
            '${engine.currentTimePs}ps',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 16, color: AppTheme.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Dialog for selecting a circuit to load.
class _LoadDialog extends StatelessWidget {
  final List<String> files;

  const _LoadDialog({required this.files});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text(
        'Load Circuit',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
      content: SizedBox(
        width: 300,
        child: files.isEmpty
            ? const Text('No saved circuits',
                style: TextStyle(color: AppTheme.textSecondary))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: files.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      files[index],
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                    leading: const Icon(Icons.cable,
                        color: AppTheme.accent),
                    onTap: () => Navigator.pop(context, files[index]),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }
}
