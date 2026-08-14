import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/circuit_canvas.dart';
import '../providers/circuit_provider.dart';
import '../providers/simulation_provider.dart';
import '../services/file_service.dart';
import '../theme/app_theme.dart';
import '../theme/glass.dart';
import '../widgets/chip_library_panel.dart';
import '../widgets/io_panel.dart';
import '../widgets/status_bar.dart';
import '../widgets/toolbar.dart';

/// The circuit editor: the second screen of the app.
class CircuitEditorScreen extends ConsumerStatefulWidget {
  /// Name shown in the editable filename field when the screen opens.
  final String initialFilename;

  const CircuitEditorScreen({super.key, this.initialFilename = 'Untitled'});

  @override
  ConsumerState<CircuitEditorScreen> createState() =>
      _CircuitEditorScreenState();
}

class _CircuitEditorScreenState extends ConsumerState<CircuitEditorScreen> {
  late final TextEditingController _filenameController =
      TextEditingController(text: widget.initialFilename);

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              _GlassHeader(
                filenameController: _filenameController,
                onBack: () => Navigator.of(context).maybePop(),
                onNew: _newCircuit,
                onSave: _saveCircuit,
                onLoad: _loadCircuit,
                onReset: _resetSimulation,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Left: chip library
                      const ChipLibraryPanel(),
                      const SizedBox(width: 12),

                      // Center: canvas with floating controls
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GlassPanel(
                                padding: const EdgeInsets.all(4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: const CircuitCanvas(),
                                ),
                              ),
                            ),
                            const Positioned(
                              top: 12,
                              left: 12,
                              child: CircuitToolbar(),
                            ),
                            Positioned(
                              top: 12,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: _SimulationControls(
                                  onChanged: () => ref
                                      .read(circuitProvider.notifier)
                                      .forceUpdate(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Right: I/O panel
                      const IOPanel(),
                    ],
                  ),
                ),
              ),

              // Bottom: status bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: GlassPanel(
                  blur: 12,
                  borderRadius: BorderRadius.circular(14),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const CircuitStatusBar(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _newCircuit() {
    ref.read(circuitProvider.notifier).newCircuit();
    _filenameController.text = 'Untitled';
  }

  Future<void> _saveCircuit() async {
    try {
      final name = _filenameController.text.trim();
      if (name.isEmpty) {
        _showSnackBar('请输入文件名');
        return;
      }
      await FileService.save(ref.read(circuitProvider), name);
      if (mounted) {
        _showSnackBar('已保存：$name');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('保存失败：$e');
      }
    }
  }

  Future<void> _loadCircuit() async {
    try {
      final files = await FileService.listSavedCircuits();
      if (!mounted) return;

      if (files.isEmpty) {
        _showSnackBar('还没有保存的电路');
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
        _showSnackBar('已载入：$selected');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('载入失败：$e');
      }
    }
  }

  void _resetSimulation() {
    final engine = ref.read(simulationEngineProvider);
    engine.resetSignals();
    ref.read(circuitProvider.notifier).forceUpdate();
  }

  void _showSnackBar(String message) {
    final p = AppTheme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: p.textPrimary),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.glassBorder),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Frosted header bar with back / file / simulation actions.
class _GlassHeader extends StatelessWidget {
  final TextEditingController filenameController;
  final VoidCallback onBack;
  final VoidCallback onNew;
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onReset;

  const _GlassHeader({
    required this.filenameController,
    required this.onBack,
    required this.onNew,
    required this.onSave,
    required this.onLoad,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          _HeaderButton(
            icon: Icons.arrow_back_ios_new,
            tooltip: '返回首页',
            onPressed: onBack,
          ),
          Icon(Icons.memory, size: 20, color: p.accent),
          const SizedBox(width: 8),
          Text(
            'LogicSim',
            style: TextStyle(
              color: p.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 170,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: p.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: filenameController,
                style: TextStyle(
                  fontSize: 12,
                  color: p.textPrimary,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: '文件名',
                ),
              ),
            ),
          ),
          const Spacer(),
          const ThemeToggleButton(showLabel: false),
          const SizedBox(width: 4),
          _HeaderButton(
            icon: Icons.add_circle_outline,
            tooltip: '新建电路',
            onPressed: onNew,
          ),
          _HeaderButton(
            icon: Icons.save_outlined,
            tooltip: '保存电路',
            onPressed: onSave,
          ),
          _HeaderButton(
            icon: Icons.folder_open,
            tooltip: '载入电路',
            onPressed: onLoad,
          ),
          _HeaderButton(
            icon: Icons.restart_alt,
            tooltip: '重置仿真',
            onPressed: onReset,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        color: AppTheme.of(context).textPrimary,
        hoverColor: AppTheme.of(context).accent.withValues(alpha: 0.12),
      ),
    );
  }
}

/// Floating glass capsule with the simulation controls.
class _SimulationControls extends ConsumerWidget {
  final VoidCallback onChanged;

  const _SimulationControls({required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final engine = ref.watch(simulationEngineProvider);
    final circuit = ref.watch(circuitProvider);

    return GlassPanel(
      blur: 14,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SmallButton(
            icon: Icons.skip_next,
            tooltip: '单步执行',
            onTap: () {
              engine.rebuild(circuit);
              engine.step();
              onChanged();
            },
          ),
          const SizedBox(width: 4),
          _SmallButton(
            icon: Icons.play_arrow,
            tooltip: '运行仿真',
            onTap: () {
              engine.rebuild(circuit);
              engine.runUntilStable();
              onChanged();
            },
          ),
          const SizedBox(width: 8),
          Text(
            '${engine.currentTimePs}ps',
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              size: 16,
              color: AppTheme.of(context).textPrimary,
            ),
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
    final p = AppTheme.of(context);

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.glassBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.folder_open, size: 18, color: p.accent),
                  const SizedBox(width: 8),
                  Text(
                    '载入电路',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.surfaceLight),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      files[index],
                      style: TextStyle(color: p.textPrimary),
                    ),
                    leading:
                        Icon(Icons.cable, color: p.accent),
                    onTap: () => Navigator.pop(context, files[index]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: p.surfaceLight,
                    foregroundColor: p.textSecondary,
                  ),
                  child: const Text('取消'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
