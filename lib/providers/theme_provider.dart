import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app is currently using the dark glass theme.
final darkModeProvider = StateProvider<bool>((ref) => false);
