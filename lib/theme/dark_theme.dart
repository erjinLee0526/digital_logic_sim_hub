import 'package:flutter/material.dart';
import '../models/signal_state.dart';

class AppTheme {
  // Primary palette
  static const Color background = Color(0xFF1A1A2E);
  static const Color surface = Color(0xFF16213E);
  static const Color surfaceLight = Color(0xFF1F3460);
  static const Color accent = Color(0xFF00D4FF);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentRed = Color(0xFFFF5252);
  static const Color accentYellow = Color(0xFFFFD740);
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFF9E9E9E);

  // Signal state colors
  static const Color signalHigh = Color(0xFF00E676);
  static const Color signalLow = Color(0xFF448AFF);
  static const Color signalHighZ = Color(0xFF9E9E9E);
  static const Color signalUnknown = Color(0xFFFF5252);

  // Chip colors
  static const Color chipBody = Color(0xFF1F3460);
  static const Color chipBorder = Color(0xFF3A5A9F);
  static const Color chipBorderSelected = Color(0xFF00D4FF);

  // Pin colors
  static const Color pinInput = Color(0xFF81D4FA);
  static const Color pinOutput = Color(0xFFFFD740);
  static const Color pinPower = Color(0xFFEF5350);
  static const Color pinGround = Color(0xFF424242);

  // Wire colors
  static const Color wireDefault = Color(0xFF546E7A);
  static const Color wireHigh = Color(0xFF00E676);
  static const Color wireLow = Color(0xFF448AFF);
  static const Color wireConflict = Color(0xFFFF5252);
  static const Color wireSelected = Color(0xFFFFD740);

  // Grid
  static const Color gridDot = Color(0xFF2A3A5A);

  // Canvas background
  static const Color canvasBg = Color(0xFF0D1117);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentGreen,
        surface: surface,
        error: accentRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent),
        ),
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 14),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 12),
        titleMedium: TextStyle(color: textPrimary, fontSize: 16),
        titleSmall: TextStyle(color: textSecondary, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaceLight,
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
    );
  }

  /// Returns a color for a given signal state (for wires and pin indicators).
  static Color colorForSignal(SignalState state) {
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
}
