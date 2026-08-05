import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/editor_provider.dart';
import '../theme/dark_theme.dart';

/// Floating toolbar with tool selection and simulation controls.
class CircuitToolbar extends ConsumerWidget {
  const CircuitToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTool = ref.watch(editorToolProvider);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.chipBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(
            icon: Icons.electric_bolt,
            label: 'Wire',
            tooltip: 'Wiring mode (W) — Click two pins to connect',
            isSelected: currentTool == EditorTool.wiring,
            onTap: () =>
                ref.read(editorToolProvider.notifier).state = EditorTool.wiring,
          ),
          const SizedBox(width: 4),
          _ToolButton(
            icon: Icons.open_with,
            label: 'Move',
            tooltip: 'Drag mode (M) — Click and drag chips',
            isSelected: currentTool == EditorTool.dragging,
            onTap: () => ref
                .read(editorToolProvider.notifier)
                .state = EditorTool.dragging,
          ),
          const SizedBox(width: 4),
          _ToolButton(
            icon: Icons.delete_outline,
            label: 'Del',
            tooltip: 'Delete mode (D) — Click to remove chips or wires',
            isSelected: currentTool == EditorTool.deleting,
            onTap: () => ref
                .read(editorToolProvider.notifier)
                .state = EditorTool.deleting,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected ? AppTheme.accent.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
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
