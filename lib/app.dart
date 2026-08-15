import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class DigitalLogicSimApp extends ConsumerWidget {
  const DigitalLogicSimApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(themePresetProvider);
    final isDay = preset == ThemePreset.dayIndustrial ||
        preset == ThemePreset.dayRefined;
    final theme = isDay ? AppTheme.lightTheme : AppTheme.darkTheme;

    return MaterialApp(
      title: 'Digital Logic Simulator',
      theme: theme,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDay ? Brightness.dark : Brightness.light,
            statusBarBrightness: isDay ? Brightness.light : Brightness.dark,
            systemNavigationBarColor:
                isDay ? const Color(0xFFF2F5FB) : const Color(0xFF17191E),
            systemNavigationBarIconBrightness:
                isDay ? Brightness.dark : Brightness.light,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeScreen(),
    );
  }
}
