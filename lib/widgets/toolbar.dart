import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/editor_provider.dart';
import '../theme/app_theme.dart';
import '../theme/glass.dart';

/// Floating glass toolbar: tool selection, chip style and pin visibility.
class CircuitToolbar extends ConsumerWidget {
  const CircuitToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTool = ref.watch(editorToolProvider);
    final p = AppTheme.of(context);

    return GlassPanel(
      blur: 14,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(
            icon: Icons.electric_bolt,
            label: '导线',
            tooltip: '连线模式（W）— 依次点击两个引脚建立连接',
            isSelected: currentTool == EditorTool.wiring,
            onTap: () => ref
                .read(editorToolProvider.notifier)
                .state = EditorTool.wiring,
          ),
          _ToolButton(
            icon: Icons.open_with,
            label: '移动',
            tooltip: '拖动模式（M）— 长按芯片进行拖拽',
            isSelected: currentTool == EditorTool.dragging,
            onTap: () => ref
                .read(editorToolProvider.notifier)
                .state = EditorTool.dragging,
          ),
          _ToolButton(
            icon: Icons.delete_outline,
            label: '删除',
            tooltip: '删除模式（D）— 点击移除元件或导线',
            isSelected: currentTool == EditorTool.deleting,
            onTap: () => ref
                .read(editorToolProvider.notifier)
                .state = EditorTool.deleting,
          ),

          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            color: p.chipBorder.withValues(alpha: 0.55),
          ),

          // Pin visibility
          const _PinToggle(),
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
    final p = AppTheme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? p.accent.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? p.accent.withValues(alpha: 0.45)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: isSelected ? p.accent : p.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? p.accent : p.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
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

/// Toggle that shows or hides the clickable pin dots on chips.
class _PinToggle extends ConsumerWidget {
  const _PinToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showPins = ref.watch(showPinsProvider);
    final p = AppTheme.of(context);

    return Tooltip(
      message: showPins ? '隐藏引脚' : '显示引脚',
      child: Material(
        color: showPins
            ? p.accent.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              ref.read(showPinsProvider.notifier).state = !showPins,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Icon(
              showPins ? Icons.circle : Icons.circle_outlined,
              size: 16,
              color: showPins ? p.accent : p.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
