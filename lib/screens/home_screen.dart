import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/circuit_provider.dart';
import '../providers/theme_provider.dart';
import '../services/file_service.dart';
import '../theme/app_theme.dart';
import '../theme/glass.dart';
import 'editor_screen.dart';

/// First screen: project title plus a list of saved circuits.
///
/// The exact layout depends on the active [ThemePreset].
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<String> _circuits = [];
  String? _selected;
  bool _listOpen = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshCircuits();
  }

  Future<void> _refreshCircuits() async {
    try {
      final files = await FileService.listSavedCircuits().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <String>[],
      );
      if (!mounted) return;
      setState(() {
        _circuits = files..sort();
        if (_selected != null && !_circuits.contains(_selected)) {
          _selected = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _circuits = [];
        _loading = false;
      });
    }
  }

  Future<void> _openCircuit() async {
    final name = _selected;
    if (name == null) return;

    try {
      final circuit = await FileService.load(name);
      ref.read(circuitProvider.notifier).loadCircuit(circuit);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('打开失败：$e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.white,
        ),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CircuitEditorScreen(initialFilename: name),
      ),
    );
    await _refreshCircuits();
  }

  Future<void> _createCircuit() async {
    ref.read(circuitProvider.notifier).newCircuit();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const CircuitEditorScreen(initialFilename: '未命名'),
      ),
    );
    await _refreshCircuits();
  }

  @override
  Widget build(BuildContext context) {
    final preset = ref.watch(themePresetProvider);

    return switch (preset) {
      ThemePreset.refinedLight || ThemePreset.refinedDark => _RefinedHomeView(
          circuits: _circuits,
          selected: _selected,
          listOpen: _listOpen,
          loading: _loading,
          onToggleList: () => setState(() => _listOpen = !_listOpen),
          onSelect: (name) => setState(() => _selected = name),
          onOpen: _openCircuit,
          onCreate: _createCircuit,
        ),
      ThemePreset.industrial => _IndustrialHomeView(
          circuits: _circuits,
          selected: _selected,
          listOpen: _listOpen,
          loading: _loading,
          onToggleList: () => setState(() => _listOpen = !_listOpen),
          onSelect: (name) => setState(() => _selected = name),
          onOpen: _openCircuit,
          onCreate: _createCircuit,
        ),
      ThemePreset.minimal => _MinimalHomeView(
          circuits: _circuits,
          selected: _selected,
          loading: _loading,
          onSelect: (name) => setState(() => _selected = name),
          onOpen: _openCircuit,
          onCreate: _createCircuit,
        ),
    };
  }
}

/// Refined glass home: centered pearl title over a collapsible glass panel.
class _RefinedHomeView extends StatelessWidget {
  final List<String> circuits;
  final String? selected;
  final bool listOpen;
  final bool loading;
  final VoidCallback onToggleList;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpen;
  final VoidCallback onCreate;

  const _RefinedHomeView({
    required this.circuits,
    required this.selected,
    required this.listOpen,
    required this.loading,
    required this.onToggleList,
    required this.onSelect,
    required this.onOpen,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 44,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GlassPanel(
                          padding: const EdgeInsets.all(18),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(24)),
                          child: Icon(
                            Icons.memory,
                            size: 44,
                            color: p.accent,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Digital Logic Simulator',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '数字逻辑电路设计与仿真',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 14,
                            letterSpacing: 5,
                          ),
                        ),
                        const SizedBox(height: 44),
                        GlassButton(
                          label: '新建电路',
                          icon: Icons.add,
                          primary: true,
                          onPressed: onCreate,
                        ),
                        const SizedBox(height: 30),
                        _SavedCircuitsPanel(
                          open: listOpen,
                          loading: loading,
                          circuits: circuits,
                          selected: selected,
                          onToggle: onToggleList,
                          onSelect: onSelect,
                          onOpen: onOpen,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 12,
                right: 12,
                child: ThemePickerButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Industrial home: graphite panel, ember accents, technical labels.
class _IndustrialHomeView extends StatelessWidget {
  final List<String> circuits;
  final String? selected;
  final bool listOpen;
  final bool loading;
  final VoidCallback onToggleList;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpen;
  final VoidCallback onCreate;

  const _IndustrialHomeView({
    required this.circuits,
    required this.selected,
    required this.listOpen,
    required this.loading,
    required this.onToggleList,
    required this.onSelect,
    required this.onOpen,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 36,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: p.accentGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: p.accentGreen
                                        .withValues(alpha: 0.55),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'LOGICSIM · 数字逻辑仿真',
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 12,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'DIGITAL LOGIC\nSIMULATOR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: 120,
                          height: 2,
                          color: p.accent,
                        ),
                        const SizedBox(height: 34),
                        GlassButton(
                          label: '新建电路',
                          icon: Icons.add,
                          primary: true,
                          onPressed: onCreate,
                        ),
                        const SizedBox(height: 30),
                        GlassPanel(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: onToggleList,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      18, 14, 14, 14),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 17,
                                        color: p.accent,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '已保存电路',
                                        style: TextStyle(
                                          color: p.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        listOpen
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: 18,
                                        color: p.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedCrossFade(
                                duration: const Duration(milliseconds: 200),
                                crossFadeState: listOpen
                                    ? CrossFadeState.showFirst
                                    : CrossFadeState.showSecond,
                                firstChild: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      14, 0, 14, 16),
                                  child: _industrialList(context),
                                ),
                                secondChild:
                                    const SizedBox(width: double.infinity),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 12,
                right: 12,
                child: ThemePickerButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _industrialList(BuildContext context) {
    final p = AppTheme.of(context);

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (circuits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            'NO CIRCUITS — 点击「新建电路」开始',
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: circuits.length,
            itemBuilder: (context, index) {
              final name = circuits[index];
              final active = name == selected;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => onSelect(name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? p.accent.withValues(alpha: 0.12)
                          : p.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: active ? p.accent : p.glassBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          active ? Icons.radio_button_checked : Icons.circle,
                          size: 9,
                          color: active ? p.accentGreen : p.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: p.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: GlassButton(
            label: selected == null ? '选择电路' : '打开「$selected」',
            icon: Icons.arrow_forward,
            onPressed: selected == null ? null : onOpen,
          ),
        ),
      ],
    );
  }
}

/// Minimal home: a left navigation rail plus a left-aligned workspace list.
/// The layout is intentionally different from the centered refined and
/// industrial screens.
class _MinimalHomeView extends StatelessWidget {
  final List<String> circuits;
  final String? selected;
  final bool loading;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpen;
  final VoidCallback onCreate;

  const _MinimalHomeView({
    required this.circuits,
    required this.selected,
    required this.loading,
    required this.onSelect,
    required this.onOpen,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left navigation rail.
            SizedBox(
              width: 208,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: p.glassBorder),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.memory, size: 18, color: p.accent),
                        const SizedBox(width: 8),
                        Text(
                          'LogicSim',
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(
                      '工作区',
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GlassButton(
                      label: '新建电路',
                      icon: Icons.add,
                      primary: true,
                      onPressed: onCreate,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '保存',
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${circuits.length} 个电路',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const ThemePickerButton(),
                  ],
                ),
              ),
            ),

            // Main content, left aligned.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(36, 32, 36, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Digital Logic Simulator',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '数字逻辑电路设计与仿真',
                        style: TextStyle(
                          color: p.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 34),
                      Row(
                        children: [
                          Text(
                            '已保存的电路',
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (!loading && circuits.isNotEmpty)
                            Text(
                              '${circuits.length}',
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Divider(height: 1, color: p.glassBorder),
                      const SizedBox(height: 8),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (circuits.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text(
                              '还没有保存的电路，点击左侧「新建电路」开始',
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        for (final name in circuits)
                          _MinimalCircuitRow(
                            name: name,
                            active: name == selected,
                            onTap: () => onSelect(name),
                            onOpen: onOpen,
                          ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GlassButton(
                            label: selected == null
                                ? '选择要打开的电路'
                                : '打开「$selected」',
                            icon: Icons.arrow_forward,
                            onPressed: selected == null ? null : onOpen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalCircuitRow extends StatelessWidget {
  final String name;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  const _MinimalCircuitRow({
    required this.name,
    required this.active,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return InkWell(
      onTap: onTap,
      onDoubleTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: p.glassBorder),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cable,
              size: 16,
              color: active ? p.accent : p.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: active ? p.accent : p.textPrimary,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (active)
              Text(
                '双击打开',
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 11,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 17,
              color: p.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible panel listing previously saved circuits (refined style).
class _SavedCircuitsPanel extends StatelessWidget {
  final bool open;
  final bool loading;
  final List<String> circuits;
  final String? selected;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpen;

  const _SavedCircuitsPanel({
    required this.open,
    required this.loading,
    required this.circuits,
    required this.selected,
    required this.onToggle,
    required this.onSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return GlassPanel(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_copy_outlined,
                    size: 18,
                    color: p.textPrimary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '已保存的电路',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState:
                open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _panelBody(context),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _panelBody(BuildContext context) {
    final p = AppTheme.of(context);

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (circuits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 32,
              color: p.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              '还没有保存的电路',
              style: TextStyle(color: p.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '点击上方「新建电路」开始设计',
              style: TextStyle(
                color: p.textSecondary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: circuits.length,
            itemBuilder: (context, index) {
              final name = circuits[index];
              return _CircuitRow(
                name: name,
                isSelected: name == selected,
                onTap: () => onSelect(name),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: GlassButton(
            label: selected == null ? '选择要打开的电路' : '打开「$selected」',
            icon: Icons.arrow_forward,
            onPressed: selected == null ? null : onOpen,
          ),
        ),
      ],
    );
  }
}

class _CircuitRow extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _CircuitRow({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? p.accent.withValues(alpha: 0.14)
            : p.glassTint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? p.accent.withValues(alpha: 0.5)
                    : p.glassBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cable,
                  size: 17,
                  color: isSelected ? p.accent : p.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isSelected ? p.accent : p.textPrimary,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: isSelected ? p.accent : p.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
