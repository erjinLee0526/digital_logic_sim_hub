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
  bool _chipDrawerOpen = true;
  bool _ioDrawerOpen = false;

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
                chipsOpen: _chipDrawerOpen,
                ioOpen: _ioDrawerOpen,
                onBack: () => Navigator.of(context).maybePop(),
                onToggleChips: () =>
                    setState(() => _chipDrawerOpen = !_chipDrawerOpen),
                onToggleIO: () =>
                    setState(() => _ioDrawerOpen = !_ioDrawerOpen),
                onNew: _newCircuit,
                onSave: _saveCircuit,
                onLoad: _loadCircuit,
                onReset: _resetSimulation,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Stack(
                    children: [
                      // Canvas glass sheet
                      Positioned.fill(
                        child: GlassPanel(
                          blur: 26,
                          color: Colors.transparent,
                          padding: const EdgeInsets.all(4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: const CircuitCanvas(),
                          ),
                        ),
                      ),

                      // Floating tool bar
                      const Positioned(
                        top: 14,
                        left: 14,
                        child: CircuitToolbar(),
                      ),

                      // Simulation controls
                      Positioned(
                        top: 14,
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

                      // Collapsible chip-library drawer
                      Positioned(
                        top: 60,
                        bottom: 8,
                        left: 8,
                        width: 252,
                        child: AnimatedSlide(
                          offset: _chipDrawerOpen
                              ? Offset.zero
                              : const Offset(-1.18, 0),
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          child: IgnorePointer(
                            ignoring: !_chipDrawerOpen,
                            child: _ModuleDrawer(
                              onClose: () =>
                                  setState(() => _chipDrawerOpen = false),
                              child: const ChipLibraryPanel(),
                            ),
                          ),
                        ),
                      ),

                      // Collapsible I/O drawer
                      Positioned(
                        top: 60,
                        bottom: 8,
                        right: 8,
                        width: 232,
                        child: AnimatedSlide(
                          offset: _ioDrawerOpen
                              ? Offset.zero
                              : const Offset(1.18, 0),
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          child: IgnorePointer(
                            ignoring: !_ioDrawerOpen,
                            child: _ModuleDrawer(
                              onClose: () =>
                                  setState(() => _ioDrawerOpen = false),
                              child: const IOPanel(),
                            ),
                          ),
                        ),
                      ),
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
  final bool chipsOpen;
  final bool ioOpen;
  final VoidCallback onBack;
  final VoidCallback onToggleChips;
  final VoidCallback onToggleIO;
  final VoidCallback onNew;
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onReset;

  const _GlassHeader({
    required this.filenameController,
    required this.chipsOpen,
    required this.ioOpen,
    required this.onBack,
    required this.onToggleChips,
    required this.onToggleIO,
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
            icon: Icons.arrow_back_rounded,
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
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          ),
          const SizedBox(width: 14),
          _ModuleToggle(
            icon: Icons.memory,
            label: '芯片库',
            active: chipsOpen,
            onTap: onToggleChips,
          ),
          const SizedBox(width: 8),
          _ModuleToggle(
            icon: Icons.tune,
            label: '输入 / 输出',
            active: ioOpen,
            onTap: onToggleIO,
          ),
          const Spacer(),
          const ThemePickerButton(showLabel: false),
          const SizedBox(width: 4),
          _HeaderButton(
            icon: Icons.add_rounded,
            tooltip: '新建电路',
            onPressed: onNew,
          ),
          _HeaderButton(
            icon: Icons.save_rounded,
            tooltip: '保存电路',
            onPressed: onSave,
          ),
          _HeaderButton(
            icon: Icons.folder_open_rounded,
            tooltip: '载入电路',
            onPressed: onLoad,
          ),
          _HeaderButton(
            icon: Icons.replay_rounded,
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
    final p = AppTheme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.glassTint.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          hoverColor: p.accent.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: p.glassShadow,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: p.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped toggle for the collapsible modules in the header bar.
class _ModuleToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModuleToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final foreground = active ? p.accent : p.textSecondary;

    return Tooltip(
      message: active ? '收起$label' : '展开$label',
      child: Material(
        color: active
            ? p.accent.withValues(alpha: 0.16)
            : p.glassTint.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? p.accent.withValues(alpha: 0.45)
                    : p.glassBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded frosted-glass drawer hosting a side module, with a close button.
class _ModuleDrawer extends StatelessWidget {
  final Widget child;
  final VoidCallback onClose;

  const _ModuleDrawer({required this.child, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return GlassPanel(
      blur: 24,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(2),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: child,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Tooltip(
              message: '收起',
              child: Material(
                color: p.glassTint,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.close, size: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
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
