import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../canvas/circuit_canvas.dart';
import '../chips/chip_factory.dart';
import '../models/chip_definition.dart';
import '../providers/circuit_provider.dart';
import '../providers/editor_provider.dart';
import '../providers/simulation_provider.dart';
import '../providers/theme_provider.dart';
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
    final preset = ref.watch(themePresetProvider);

    return switch (preset) {
      ThemePreset.refinedLight || ThemePreset.refinedDark => _RefinedEditorView(
          filenameController: _filenameController,
          chipDrawerOpen: _chipDrawerOpen,
          ioDrawerOpen: _ioDrawerOpen,
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
      ThemePreset.industrial => _FixedEditorView(
          filenameController: _filenameController,
          technical: true,
          onBack: () => Navigator.of(context).maybePop(),
          onNew: _newCircuit,
          onSave: _saveCircuit,
          onLoad: _loadCircuit,
          onReset: _resetSimulation,
        ),
      ThemePreset.minimal => _MinimalEditorView(
          filenameController: _filenameController,
          onBack: () => Navigator.of(context).maybePop(),
          onNew: _newCircuit,
          onSave: _saveCircuit,
          onLoad: _loadCircuit,
          onReset: _resetSimulation,
        ),
    };
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

/// Refined glass editor: floating header, sliding module drawers, glass
/// status strip.
class _RefinedEditorView extends ConsumerWidget {
  final TextEditingController filenameController;
  final bool chipDrawerOpen;
  final bool ioDrawerOpen;
  final VoidCallback onBack;
  final VoidCallback onToggleChips;
  final VoidCallback onToggleIO;
  final VoidCallback onNew;
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onReset;

  const _RefinedEditorView({
    required this.filenameController,
    required this.chipDrawerOpen,
    required this.ioDrawerOpen,
    required this.onBack,
    required this.onToggleChips,
    required this.onToggleIO,
    required this.onNew,
    required this.onSave,
    required this.onLoad,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              _GlassHeader(
                filenameController: filenameController,
                chipsOpen: chipDrawerOpen,
                ioOpen: ioDrawerOpen,
                onBack: onBack,
                onToggleChips: onToggleChips,
                onToggleIO: onToggleIO,
                onNew: onNew,
                onSave: onSave,
                onLoad: onLoad,
                onReset: onReset,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Stack(
                    children: [
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
                      const Positioned(
                        top: 14,
                        left: 14,
                        child: CircuitToolbar(),
                      ),
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
                      Positioned(
                        top: 60,
                        bottom: 8,
                        left: 8,
                        width: 252,
                        child: AnimatedSlide(
                          offset: chipDrawerOpen
                              ? Offset.zero
                              : const Offset(-1.18, 0),
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          child: IgnorePointer(
                            ignoring: !chipDrawerOpen,
                            child: _ModuleDrawer(
                              onClose: onToggleChips,
                              child: const ChipLibraryPanel(),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 60,
                        bottom: 8,
                        right: 8,
                        width: 232,
                        child: AnimatedSlide(
                          offset: ioDrawerOpen
                              ? Offset.zero
                              : const Offset(1.18, 0),
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          child: IgnorePointer(
                            ignoring: !ioDrawerOpen,
                            child: _ModuleDrawer(
                              onClose: onToggleIO,
                              child: const IOPanel(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
}

/// Industrial and minimal editors share a fixed-panel layout; the palette
/// supplies the angular/rounded, dark/light visual language.
class _FixedEditorView extends ConsumerWidget {
  final TextEditingController filenameController;
  final bool technical;
  final VoidCallback onBack;
  final VoidCallback onNew;
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onReset;

  const _FixedEditorView({
    required this.filenameController,
    required this.technical,
    required this.onBack,
    required this.onNew,
    required this.onSave,
    required this.onLoad,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              GlassPanel(
                margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    _HeaderButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: '返回首页',
                      onPressed: onBack,
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.memory, size: 18, color: p.accent),
                    const SizedBox(width: 8),
                    Text(
                      technical ? 'LOGICSIM' : 'LogicSim',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: technical ? 2 : 0,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.surfaceLight,
                            borderRadius: BorderRadius.circular(
                                p.panelRadius * 0.6),
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
                    const Spacer(),
                    const ThemePickerButton(showLabel: false),
                    const SizedBox(width: 6),
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
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 248,
                        child: GlassPanel(child: ChipLibraryPanel()),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GlassPanel(
                                color: Colors.transparent,
                                padding: const EdgeInsets.all(3),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      p.panelRadius * 0.6),
                                  child: const CircuitCanvas(),
                                ),
                              ),
                            ),
                            const Positioned(
                              top: 10,
                              left: 10,
                              child: CircuitToolbar(),
                            ),
                            Positioned(
                              top: 10,
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
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 224,
                        child: GlassPanel(child: IOPanel()),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: GlassPanel(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: CircuitStatusBar(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal editor: thin hairline top bar, a vertical tool rail between the
/// chip library and the canvas, and hairline-separated side panels.
class _MinimalEditorView extends ConsumerStatefulWidget {
  final TextEditingController filenameController;
  final VoidCallback onBack;
  final VoidCallback onNew;
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onReset;

  const _MinimalEditorView({
    required this.filenameController,
    required this.onBack,
    required this.onNew,
    required this.onSave,
    required this.onLoad,
    required this.onReset,
  });

  @override
  ConsumerState<_MinimalEditorView> createState() => _MinimalEditorViewState();
}

class _MinimalEditorViewState extends ConsumerState<_MinimalEditorView> {
  bool _ioOpen = false;

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            // Flat hairline top bar.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(
                  bottom: BorderSide(color: p.glassBorder),
                ),
              ),
              child: Row(
                children: [
                  _MinimalHeaderAction(
                    icon: Icons.arrow_back_rounded,
                    tooltip: '返回首页',
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'LogicSim',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: widget.filenameController,
                      style: TextStyle(
                        fontSize: 13,
                        color: p.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '文件名',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        fillColor: p.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(p.panelRadius * 0.6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const ThemePickerButton(showLabel: false),
                  const SizedBox(width: 12),
                  _MinimalHeaderAction(
                    icon: Icons.add_rounded,
                    tooltip: '新建电路',
                    onPressed: widget.onNew,
                  ),
                  _MinimalHeaderAction(
                    icon: Icons.save_rounded,
                    tooltip: '保存电路',
                    onPressed: widget.onSave,
                  ),
                  _MinimalHeaderAction(
                    icon: Icons.folder_open_rounded,
                    tooltip: '载入电路',
                    onPressed: widget.onLoad,
                  ),
                  _MinimalHeaderAction(
                    icon: Icons.replay_rounded,
                    tooltip: '重置仿真',
                    onPressed: widget.onReset,
                  ),
                ],
              ),
            ),

            // Tool + module strip below the top bar.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(
                  bottom: BorderSide(color: p.glassBorder),
                ),
              ),
              child: Row(
                children: [
                  const _MinimalToolSegmented(),
                  const SizedBox(width: 16),
                  Container(width: 1, height: 20, color: p.glassBorder),
                  const SizedBox(width: 16),
                  _MinimalDropdownToggle(
                    open: _ioOpen,
                    onTap: () => setState(() => _ioOpen = !_ioOpen),
                  ),
                  const Spacer(),
                  const _MinimalPinToggle(),
                ],
              ),
            ),

            // Collapsible I/O dropdown.
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _ioOpen
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Container(
                height: 190,
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border(
                    bottom: BorderSide(color: p.glassBorder),
                  ),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 640,
                    child: IOPanel(),
                  ),
                ),
              ),
              secondChild: const SizedBox(width: double.infinity),
            ),

            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: p.canvasBg,
                      child: const CircuitCanvas(),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 16,
                    child: _SimulationControls(
                      onChanged: () => ref
                          .read(circuitProvider.notifier)
                          .forceUpdate(),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom chip shelf.
            const _MinimalChipShelf(),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(
                  top: BorderSide(color: p.glassBorder),
                ),
              ),
              child: const CircuitStatusBar(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented tool buttons shown in the minimal top strip.
class _MinimalToolSegmented extends ConsumerWidget {
  const _MinimalToolSegmented();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final tool = ref.watch(editorToolProvider);

    Widget option(EditorTool value, String label) {
      final active = tool == value;
      return Tooltip(
        message: label,
        child: InkWell(
          onTap: () => ref.read(editorToolProvider.notifier).state = value,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? p.accent : p.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        option(EditorTool.wiring, '导线'),
        option(EditorTool.dragging, '移动'),
        option(EditorTool.deleting, '删除'),
      ],
    );
  }
}

/// Collapsible dropdown header for the I/O module.
class _MinimalDropdownToggle extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;

  const _MinimalDropdownToggle({required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Tooltip(
      message: '输入 / 输出',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 16, color: p.textPrimary),
              const SizedBox(width: 6),
              Text(
                '输入 / 输出',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pin visibility toggle in the minimal top strip.
class _MinimalPinToggle extends ConsumerWidget {
  const _MinimalPinToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);
    final showPins = ref.watch(showPinsProvider);

    return Tooltip(
      message: showPins ? '隐藏引脚' : '显示引脚',
      child: InkWell(
        onTap: () =>
            ref.read(showPinsProvider.notifier).state = !showPins,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            showPins ? Icons.circle : Icons.circle_outlined,
            size: 16,
            color: showPins ? p.accent : p.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Bottom horizontal chip library for the minimal theme.
class _MinimalChipShelf extends ConsumerStatefulWidget {
  const _MinimalChipShelf();

  @override
  ConsumerState<_MinimalChipShelf> createState() => _MinimalChipShelfState();
}

class _MinimalChipShelfState extends ConsumerState<_MinimalChipShelf> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChipDefinition> get _chips {
    final all = ChipFactory.allDefinitions;
    // 搜索只匹配型号名（model），不匹配功能描述（description）。
    return all.where((c) => c.matchesSearch(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final chips = _chips;

    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(
          top: BorderSide(color: p.glassBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 190,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 12, color: p.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '搜索芯片',
                  hintStyle:
                      TextStyle(fontSize: 12, color: p.textSecondary),
                  prefixIcon:
                      Icon(Icons.search, size: 16, color: p.textSecondary),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 48, color: p.glassBorder),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              itemCount: chips.length,
              itemBuilder: (context, index) =>
                  _ShelfChipCard(definition: chips[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfChipCard extends ConsumerWidget {
  final ChipDefinition definition;

  const _ShelfChipCard({required this.definition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    return Tooltip(
      message: definition.description,
      child: Container(
        width: 112,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Material(
          color: p.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              final random = Random();
              final x = 420.0 + random.nextDouble() * 180 - 90;
              final y = 320.0 + random.nextDouble() * 160 - 80;
              ref
                  .read(circuitProvider.notifier)
                  .addChip(definition.model, Offset(x, y));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.model,
                    style: TextStyle(
                      color: p.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: Text(
                      definition.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimalHeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MinimalHeaderAction({
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
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          hoverColor: p.accent.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 19, color: p.textPrimary),
          ),
        ),
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
