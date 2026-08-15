import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/editor_provider.dart';
import '../providers/theme_provider.dart';
import 'app_theme.dart';

/// Soft gradient backdrop behind the frosted surfaces.
///
/// The translucent [GlassPanel] surfaces need colorful content behind them
/// for the blur to be visible, so screens place this behind their glass.
class GlassBackground extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;

  const GlassBackground({super.key, required this.child, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final gradient = p.isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF191C25),
              Color(0xFF222530),
              Color(0xFF191F26),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE5ECFF),
              Color(0xFFF6F4FF),
              Color(0xFFE8F7F1),
            ],
          );

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _GlowBlob(
              color: p.isDark
                  ? const Color(0xFF35406A)
                  : const Color(0xFFB7CEFF),
              alignment: const Alignment(-0.85, -0.95),
              size: 460,
              opacity: p.isDark ? 0.42 : 0.62,
            ),
            _GlowBlob(
              color: p.isDark
                  ? const Color(0xFF2B5144)
                  : const Color(0xFFBDF2DE),
              alignment: const Alignment(0.95, -0.55),
              size: 400,
              opacity: p.isDark ? 0.38 : 0.62,
            ),
            _GlowBlob(
              color: p.isDark
                  ? const Color(0xFF523A50)
                  : const Color(0xFFFFD6E7),
              alignment: const Alignment(-0.7, 1.1),
              size: 420,
              opacity: p.isDark ? 0.36 : 0.62,
            ),
            _GlowBlob(
              color: p.isDark
                  ? const Color(0xFF53452D)
                  : const Color(0xFFFBE4BF),
              alignment: const Alignment(0.8, 1.0),
              size: 340,
              opacity: p.isDark ? 0.34 : 0.62,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final Alignment alignment;
  final double size;
  final double opacity;

  const _GlowBlob({
    required this.color,
    required this.alignment,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A frosted-glass surface: translucent tint, backdrop blur, hairline border
/// and a soft drop shadow. Colors follow the active light/dark palette.
class GlassPanel extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final double? tintOpacity;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double? width;
  final double? height;

  const GlassPanel({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 20,
    this.tintOpacity,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final radius = borderRadius ?? BorderRadius.circular(18);
    final tint = color ??
        (tintOpacity != null
            ? Colors.white.withValues(alpha: tintOpacity!)
            : p.glassTint);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? p.glassBorder,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: p.glassShadow,
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// Pill-shaped translucent action button.
class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;

  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final enabled = onPressed != null;
    final foreground = primary ? p.accent : p.textPrimary;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: primary
            ? p.accent.withValues(alpha: 0.14)
            : p.glassTint,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: primary
                    ? p.accent.withValues(alpha: 0.42)
                    : p.glassBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: p.glassShadow,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

/// A glass button that opens the theme preset picker popup.
class ThemePickerButton extends ConsumerWidget {
  final bool showLabel;

  const ThemePickerButton({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(themePresetProvider);
    final p = AppTheme.of(context);
    final (label, icon) = switch (preset) {
      ThemePreset.dayIndustrial => ('日间工业', Icons.memory),
      ThemePreset.dayRefined => ('日间精致', Icons.auto_awesome),
      ThemePreset.nightIndustrial => ('夜间工业', Icons.memory),
      ThemePreset.nightRefined => ('夜间精致', Icons.auto_awesome),
    };

    Future<void> openPicker() async {
      final selected = await showDialog<ThemePreset>(
        context: context,
        builder: (_) => const _ThemePickerDialog(),
      );
      if (selected == null) return;
      ref.read(themePresetProvider.notifier).state = selected;
      final industrial = selected == ThemePreset.dayIndustrial ||
          selected == ThemePreset.nightIndustrial;
      ref.read(chipStyleProvider.notifier).state =
          industrial ? ChipStyle.industrial : ChipStyle.refined;
      ref.read(showPinsProvider.notifier).state = industrial;
    }

    if (!showLabel) {
      return Tooltip(
        message: '主题：$label',
        child: Material(
          color: p.glassTint.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: openPicker,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.glassBorder),
              ),
              child: Icon(
                icon,
                size: 20,
                color: p.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: p.glassTint,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: openPicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.glassBorder),
            boxShadow: [
              BoxShadow(
                color: p.glassShadow,
                blurRadius: 18,
                offset: const Offset(0, 6),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: p.textPrimary),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.expand_more, size: 18, color: p.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small popup listing the four theme presets.
class _ThemePickerDialog extends StatelessWidget {
  const _ThemePickerDialog();

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: GlassPanel(
        blur: 28,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, size: 18, color: p.accent),
                const SizedBox(width: 8),
                Text(
                  '选择主题',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, size: 16, color: p.textSecondary),
                  tooltip: '关闭',
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ThemeOption(
              preset: ThemePreset.dayIndustrial,
              title: '日间工业',
              subtitle: '白色界面 · 经典芯片',
              preview: [
                AppTheme.light.canvasBgIndustrial,
                AppTheme.light.chipBodyIndustrial,
                AppTheme.light.accent,
              ],
            ),
            _ThemeOption(
              preset: ThemePreset.dayRefined,
              title: '日间精致',
              subtitle: '白色界面 · 珠光芯片',
              preview: [
                AppTheme.light.canvasBg,
                AppTheme.light.chipBodyRefined,
                AppTheme.light.accent,
              ],
            ),
            _ThemeOption(
              preset: ThemePreset.nightIndustrial,
              title: '夜间工业',
              subtitle: '深色界面 · 经典芯片',
              preview: [
                AppTheme.dark.canvasBgIndustrial,
                AppTheme.dark.chipBodyIndustrial,
                AppTheme.dark.accent,
              ],
            ),
            _ThemeOption(
              preset: ThemePreset.nightRefined,
              title: '夜间精致',
              subtitle: '深色界面 · 珠光芯片',
              preview: [
                AppTheme.dark.canvasBg,
                AppTheme.dark.chipBodyRefined,
                AppTheme.dark.accent,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends ConsumerWidget {
  final ThemePreset preset;
  final String title;
  final String subtitle;
  final List<Color> preview;

  const _ThemeOption({
    required this.preset,
    required this.title,
    required this.subtitle,
    required this.preview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themePresetProvider);
    final p = AppTheme.of(context);
    final active = current == preset;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: active
            ? p.accent.withValues(alpha: 0.16)
            : p.glassTint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context, preset),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? p.accent.withValues(alpha: 0.5)
                    : p.glassBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 30,
                  decoration: BoxDecoration(
                    color: preview[0],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _PreviewDot(color: preview[1]),
                      _PreviewDot(color: preview[2]),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: active ? p.accent : p.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: p.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  active ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: active ? p.accent : p.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewDot extends StatelessWidget {
  final Color color;

  const _PreviewDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
    );
  }
}
