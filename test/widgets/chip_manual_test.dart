import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls86.dart';
import 'package:digital_logic_sim/chips/ls74ls266.dart';
import 'package:digital_logic_sim/theme/app_theme.dart';
import 'package:digital_logic_sim/widgets/chip_library_panel.dart';
import 'package:digital_logic_sim/widgets/chip_manual.dart';

void main() {
  testWidgets('chip manual renders header, pinout, and truth tables',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
      theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: ChipManualDialog(definition: Chip74LS86()),
          ),
        ),
      ),
    );

    expect(find.text('74LS86'), findsOneWidget);
    expect(find.text('功能概述'), findsOneWidget);
    expect(find.text('引脚表'), findsOneWidget);
    expect(find.text('真值表'), findsOneWidget);
    expect(find.text('组合逻辑'), findsOneWidget);
    // Identical gates are summarized with a single representative table.
    expect(find.textContaining('各组逻辑行为一致'), findsOneWidget);
    expect(find.text('门 1'), findsWidgets);
    expect(find.text('门 4'), findsWidgets);
    // Truth-table output values rendered with signal colors.
    expect(find.text('1'), findsWidgets);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('chip manual shows open-collector notes for 74LS266',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
      theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: ChipManualDialog(definition: Chip74LS266()),
          ),
        ),
      ),
    );

    expect(find.text('说明'), findsOneWidget);
    expect(find.textContaining('集电极开路'), findsWidgets);
    // Floating open-collector outputs appear as Z in the truth tables.
    expect(find.text('Z'), findsWidgets);
  });

  testWidgets('library info button opens the chip manual', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
      theme: AppTheme.lightTheme,
          home: const Scaffold(body: ChipLibraryPanel()),
        ),
      ),
    );

    // The first tile is 74LS00.
    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();

    expect(find.byType(ChipManualDialog), findsOneWidget);
    expect(find.text('真值表'), findsOneWidget);
  });
}
