import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The selectable visual themes of the app.
enum ThemePreset {
  /// Light glass UI with the classic industrial chip look.
  dayIndustrial,

  /// Light glass UI with the refined pearl chip look.
  dayRefined,

  /// Dark gray glass UI with the classic industrial chip look.
  nightIndustrial,

  /// Dark gray glass UI with the refined pearl chip look.
  nightRefined,
}

/// The currently selected theme preset.
final themePresetProvider =
    StateProvider<ThemePreset>((ref) => ThemePreset.dayIndustrial);
