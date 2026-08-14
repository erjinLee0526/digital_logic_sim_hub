import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/circuit_provider.dart';
import '../services/file_service.dart';
import '../theme/app_theme.dart';
import '../theme/glass.dart';
import 'editor_screen.dart';

/// First screen: project title plus a collapsible list of saved circuits.
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
      // File access is unavailable (e.g. in tests); treat the list as empty.
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
          backgroundColor: Colors.white.withValues(alpha: 0.92),
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
                          onPressed: _createCircuit,
                        ),
                        const SizedBox(height: 30),
                        _SavedCircuitsPanel(
                          open: _listOpen,
                          loading: _loading,
                          circuits: _circuits,
                          selected: _selected,
                          onToggle: () =>
                              setState(() => _listOpen = !_listOpen),
                          onSelect: (name) =>
                              setState(() => _selected = name),
                          onOpen: _openCircuit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Light/dark toggle, top-right.
              const Positioned(
                top: 12,
                right: 12,
                child: ThemeToggleButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsible panel listing previously saved circuits.
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
          // Header / collapse toggle
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

          // Collapsible body
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
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13,
              ),
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
