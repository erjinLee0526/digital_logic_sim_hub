import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'editor_provider.dart';

/// The selectable visual themes of the app.
///
/// Each preset owns its own palette, home screen design, and editor design.
enum ThemePreset {
  /// Refined glass look in light mode.
  refinedLight,

  /// Refined glass look in dark mode.
  refinedDark,

  /// Industrial instrument-panel look.
  industrial,

  /// Minimal flat look.
  minimal,
}

/// The chip rendering style used by [preset].
ChipStyle chipStyleForPreset(ThemePreset preset) {
  switch (preset) {
    case ThemePreset.refinedLight:
    case ThemePreset.refinedDark:
      return ChipStyle.refined;
    case ThemePreset.industrial:
    case ThemePreset.minimal:
      return ChipStyle.industrial;
  }
}

/// Whether pin dots are visible by default for [preset].
bool showPinsForPreset(ThemePreset preset) {
  switch (preset) {
    case ThemePreset.refinedLight:
    case ThemePreset.refinedDark:
      return false;
    case ThemePreset.industrial:
    case ThemePreset.minimal:
      return true;
  }
}

/// The currently selected theme preset.
final themePresetProvider =
    StateProvider<ThemePreset>((ref) => ThemePreset.refinedLight);
