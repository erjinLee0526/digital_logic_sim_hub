import 'package:flutter/material.dart';

import '../models/signal_state.dart';

/// The full color set for one UI mode.
///
/// It is registered as a [ThemeExtension] so that widgets can read the active
/// palette with [AppTheme.of] and repaint automatically when light/dark mode
/// toggles.
class ThemePalette extends ThemeExtension<ThemePalette> {
  final bool isDark;

  // Base surfaces.
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color accent;
  final Color accentGreen;
  final Color accentRed;
  final Color accentYellow;
  final Color textPrimary;
  final Color textSecondary;

  // Signal state colors.
  final Color signalHigh;
  final Color signalLow;
  final Color signalHighZ;
  final Color signalUnknown;

  // Chip colors. The body is translucent so chips separate from the canvas
  // through transparency and gray level rather than a solid fill.
  final Color chipBody;
  final Color chipBorder;
  final Color chipBorderSelected;
  final Color chipBodyIndustrial;
  final Color chipBorderIndustrial;
  final Color chipTextIndustrial;
  final Color chipTextSecondaryIndustrial;
  final Color chipBodyRefined;
  final Color chipBorderRefined;
  final Color chipGlossRefined;
  final Color chipTextRefined;
  final Color chipTextSecondaryRefined;
  final Color chipAccentRefined;

  // Pin colors.
  final Color pinInput;
  final Color pinOutput;
  final Color pinPower;
  final Color pinGround;

  // Wire colors.
  final Color wireDefault;
  final Color wireHigh;
  final Color wireLow;
  final Color wireConflict;
  final Color wireSelected;

  // Canvas.
  final Color gridDot;
  final Color canvasBg;
  final Color gridDotIndustrial;
  final Color canvasBgIndustrial;

  // Glass surfaces.
  final Color glassTint;
  final Color glassBorder;
  final Color glassShadow;

  const ThemePalette({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.accent,
    required this.accentGreen,
    required this.accentRed,
    required this.accentYellow,
    required this.textPrimary,
    required this.textSecondary,
    required this.signalHigh,
    required this.signalLow,
    required this.signalHighZ,
    required this.signalUnknown,
    required this.chipBody,
    required this.chipBorder,
    required this.chipBorderSelected,
    required this.chipBodyIndustrial,
    required this.chipBorderIndustrial,
    required this.chipTextIndustrial,
    required this.chipTextSecondaryIndustrial,
    required this.chipBodyRefined,
    required this.chipBorderRefined,
    required this.chipGlossRefined,
    required this.chipTextRefined,
    required this.chipTextSecondaryRefined,
    required this.chipAccentRefined,
    required this.pinInput,
    required this.pinOutput,
    required this.pinPower,
    required this.pinGround,
    required this.wireDefault,
    required this.wireHigh,
    required this.wireLow,
    required this.wireConflict,
    required this.wireSelected,
    required this.gridDot,
    required this.canvasBg,
    required this.gridDotIndustrial,
    required this.canvasBgIndustrial,
    required this.glassTint,
    required this.glassBorder,
    required this.glassShadow,
  });

  /// Returns the display color for a signal state.
  Color colorForSignal(SignalState state) {
    switch (state) {
      case SignalState.high:
        return signalHigh;
      case SignalState.low:
        return signalLow;
      case SignalState.highZ:
        return signalHighZ;
      case SignalState.unknown:
        return signalUnknown;
    }
  }

  @override
  ThemePalette copyWith({
    bool? isDark,
    Color? background,
    Color? surface,
    Color? surfaceLight,
    Color? accent,
    Color? accentGreen,
    Color? accentRed,
    Color? accentYellow,
    Color? textPrimary,
    Color? textSecondary,
    Color? signalHigh,
    Color? signalLow,
    Color? signalHighZ,
    Color? signalUnknown,
    Color? chipBody,
    Color? chipBorder,
    Color? chipBorderSelected,
    Color? chipBodyIndustrial,
    Color? chipBorderIndustrial,
    Color? chipTextIndustrial,
    Color? chipTextSecondaryIndustrial,
    Color? chipBodyRefined,
    Color? chipBorderRefined,
    Color? chipGlossRefined,
    Color? chipTextRefined,
    Color? chipTextSecondaryRefined,
    Color? chipAccentRefined,
    Color? pinInput,
    Color? pinOutput,
    Color? pinPower,
    Color? pinGround,
    Color? wireDefault,
    Color? wireHigh,
    Color? wireLow,
    Color? wireConflict,
    Color? wireSelected,
    Color? gridDot,
    Color? canvasBg,
    Color? gridDotIndustrial,
    Color? canvasBgIndustrial,
    Color? glassTint,
    Color? glassBorder,
    Color? glassShadow,
  }) {
    return ThemePalette(
      isDark: isDark ?? this.isDark,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      accent: accent ?? this.accent,
      accentGreen: accentGreen ?? this.accentGreen,
      accentRed: accentRed ?? this.accentRed,
      accentYellow: accentYellow ?? this.accentYellow,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      signalHigh: signalHigh ?? this.signalHigh,
      signalLow: signalLow ?? this.signalLow,
      signalHighZ: signalHighZ ?? this.signalHighZ,
      signalUnknown: signalUnknown ?? this.signalUnknown,
      chipBody: chipBody ?? this.chipBody,
      chipBorder: chipBorder ?? this.chipBorder,
      chipBorderSelected: chipBorderSelected ?? this.chipBorderSelected,
      chipBodyIndustrial: chipBodyIndustrial ?? this.chipBodyIndustrial,
      chipBorderIndustrial: chipBorderIndustrial ?? this.chipBorderIndustrial,
      chipTextIndustrial: chipTextIndustrial ?? this.chipTextIndustrial,
      chipTextSecondaryIndustrial:
          chipTextSecondaryIndustrial ?? this.chipTextSecondaryIndustrial,
      chipBodyRefined: chipBodyRefined ?? this.chipBodyRefined,
      chipBorderRefined: chipBorderRefined ?? this.chipBorderRefined,
      chipGlossRefined: chipGlossRefined ?? this.chipGlossRefined,
      chipTextRefined: chipTextRefined ?? this.chipTextRefined,
      chipTextSecondaryRefined:
          chipTextSecondaryRefined ?? this.chipTextSecondaryRefined,
      chipAccentRefined: chipAccentRefined ?? this.chipAccentRefined,
      pinInput: pinInput ?? this.pinInput,
      pinOutput: pinOutput ?? this.pinOutput,
      pinPower: pinPower ?? this.pinPower,
      pinGround: pinGround ?? this.pinGround,
      wireDefault: wireDefault ?? this.wireDefault,
      wireHigh: wireHigh ?? this.wireHigh,
      wireLow: wireLow ?? this.wireLow,
      wireConflict: wireConflict ?? this.wireConflict,
      wireSelected: wireSelected ?? this.wireSelected,
      gridDot: gridDot ?? this.gridDot,
      canvasBg: canvasBg ?? this.canvasBg,
      gridDotIndustrial: gridDotIndustrial ?? this.gridDotIndustrial,
      canvasBgIndustrial: canvasBgIndustrial ?? this.canvasBgIndustrial,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
    );
  }

  @override
  ThemePalette lerp(ThemePalette? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

/// Light and dark glass themes plus the helper to read the active palette.
class AppTheme {
  AppTheme._();

  static const ThemePalette light = ThemePalette(
    isDark: false,
    background: Color(0xFFF2F5FB),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFEDF2FA),
    accent: Color(0xFF4E6EF2),
    accentGreen: Color(0xFF17A36B),
    accentRed: Color(0xFFE5484D),
    accentYellow: Color(0xFFF0A21C),
    textPrimary: Color(0xFF1F2A44),
    textSecondary: Color(0xFF66758C),
    signalHigh: Color(0xFF0FA968),
    signalLow: Color(0xFF2F6FED),
    signalHighZ: Color(0xFF9AA6B8),
    signalUnknown: Color(0xFFE5484D),
    chipBody: Color(0xF5F7F9FC),
    chipBorder: Color(0xFFB9C6DA),
    chipBorderSelected: Color(0xFF4E6EF2),
    chipBodyIndustrial: Color(0xFF232A30),
    chipBorderIndustrial: Color(0xFF4A6356),
    chipTextIndustrial: Color(0xFFF2F6F8),
    chipTextSecondaryIndustrial: Color(0xFFB8C3CC),
    chipBodyRefined: Color(0xF0E9ECF2),
    chipBorderRefined: Color(0xFFAEB8C8),
    chipGlossRefined: Color(0xFFFFFFFF),
    chipTextRefined: Color(0xFF33405E),
    chipTextSecondaryRefined: Color(0xFF66758C),
    chipAccentRefined: Color(0xFF4E6EF2),
    pinInput: Color(0xFF63A5F5),
    pinOutput: Color(0xFFF0A21C),
    pinPower: Color(0xFFE5484D),
    pinGround: Color(0xFF6B7890),
    wireDefault: Color(0xFF9AA6B8),
    wireHigh: Color(0xFF0FA968),
    wireLow: Color(0xFF2F6FED),
    wireConflict: Color(0xFFE5484D),
    wireSelected: Color(0xFFF0A21C),
    gridDot: Color(0xFFB7C7DC),
    canvasBg: Color(0x4DFFFFFF),
    gridDotIndustrial: Color(0xFF1F5C29),
    canvasBgIndustrial: Color(0xFF2E7D32),
    glassTint: Color(0x94FFFFFF),
    glassBorder: Color(0xB8FFFFFF),
    glassShadow: Color(0x21384A66),
  );

  static const ThemePalette dark = ThemePalette(
    isDark: true,
    background: Color(0xFF17191E),
    surface: Color(0xFF20232A),
    surfaceLight: Color(0xFF2A2E37),
    accent: Color(0xFF7C9BFF),
    accentGreen: Color(0xFF3FD69B),
    accentRed: Color(0xFFFF6B6B),
    accentYellow: Color(0xFFF5C044),
    textPrimary: Color(0xFFE9ECF2),
    textSecondary: Color(0xFF9AA3B2),
    signalHigh: Color(0xFF3FD69B),
    signalLow: Color(0xFF6C9BFF),
    signalHighZ: Color(0xFF7C8494),
    signalUnknown: Color(0xFFFF6B6B),
    chipBody: Color(0xDE303845),
    chipBorder: Color(0xFF4A5262),
    chipBorderSelected: Color(0xFF7C9BFF),
    chipBodyIndustrial: Color(0xFF232A30),
    chipBorderIndustrial: Color(0xFF4A6356),
    chipTextIndustrial: Color(0xFFF2F6F8),
    chipTextSecondaryIndustrial: Color(0xFFB8C3CC),
    chipBodyRefined: Color(0xE8464F5F),
    chipBorderRefined: Color(0xFF818B9C),
    chipGlossRefined: Color(0xFFFFFFFF),
    chipTextRefined: Color(0xFFE9ECF2),
    chipTextSecondaryRefined: Color(0xFFB7BFCD),
    chipAccentRefined: Color(0xFF8FA8FF),
    pinInput: Color(0xFF6FAEF7),
    pinOutput: Color(0xFFF5C044),
    pinPower: Color(0xFFFF6B6B),
    pinGround: Color(0xFF8A93A3),
    wireDefault: Color(0xFF7C8494),
    wireHigh: Color(0xFF3FD69B),
    wireLow: Color(0xFF6C9BFF),
    wireConflict: Color(0xFFFF6B6B),
    wireSelected: Color(0xFFF5C044),
    gridDot: Color(0xFF3A4250),
    canvasBg: Color(0xE620232A),
    gridDotIndustrial: Color(0xFF1F5C29),
    canvasBgIndustrial: Color(0xFF2E7D32),
    glassTint: Color(0x8A23262D),
    glassBorder: Color(0x4DFFFFFF),
    glassShadow: Color(0x66000000),
  );

  static ThemeData get lightTheme => _build(light);

  static ThemeData get darkTheme => _build(dark);

  /// The active palette for the current [ThemeMode].
  static ThemePalette of(BuildContext context) =>
      Theme.of(context).extension<ThemePalette>() ?? light;

  static ThemeData _build(ThemePalette p) {
    final base = p.isDark
        ? ThemeData(brightness: Brightness.dark, useMaterial3: true)
        : ThemeData(brightness: Brightness.light, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      colorScheme: ColorScheme(
        brightness: p.isDark ? Brightness.dark : Brightness.light,
        primary: p.accent,
        onPrimary: Colors.white,
        secondary: p.accentGreen,
        onSecondary: Colors.white,
        error: p.accentRed,
        onError: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: p.surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceLight,
        hintStyle: TextStyle(color: p.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.accent, width: 1.4),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: p.textPrimary, fontSize: 14),
        bodyMedium: TextStyle(color: p.textSecondary, fontSize: 12),
        titleMedium: TextStyle(color: p.textPrimary, fontSize: 16),
        titleSmall: TextStyle(color: p.textSecondary, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
      dividerColor: p.chipBorder,
      extensions: [p],
    );
  }
}
