import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_logic_sim/app.dart';
import 'package:digital_logic_sim/providers/editor_provider.dart';

void main() {
  testWidgets('renders the home screen with project title and circuit list',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DigitalLogicSimApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Digital Logic Simulator'), findsOneWidget);
    expect(find.text('已保存的电路'), findsOneWidget);
    expect(find.text('新建电路'), findsOneWidget);
  });

  testWidgets('creating a new circuit opens the editor screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DigitalLogicSimApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建电路'));
    await tester.pumpAndSettle();

    expect(find.text('LogicSim'), findsOneWidget);
    expect(find.text('输入 / 输出'), findsWidgets);
    expect(find.text('芯片库'), findsWidgets);
  });

  testWidgets('theme picker switches between presets',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DigitalLogicSimApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('浅色精致'));
    await tester.pumpAndSettle();
    expect(find.text('选择主题'), findsOneWidget);

    await tester.tap(find.text('深色精致'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(find.text('深色精致'), findsOneWidget);
  });

  testWidgets('theme preset drives chip style and pin visibility',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DigitalLogicSimApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建电路'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.text('LogicSim')),
    );
    expect(container.read(chipStyleProvider), ChipStyle.refined);
    expect(container.read(showPinsProvider), isFalse);

    // Open the theme picker from the editor header and pick industrial.
    await tester.tap(find.byTooltip('主题：浅色精致'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工业'));
    await tester.pumpAndSettle();

    expect(container.read(chipStyleProvider), ChipStyle.industrial);
    expect(container.read(showPinsProvider), isTrue);
  });

  testWidgets('pin toggle shows and hides pin dots',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DigitalLogicSimApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建电路'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.text('LogicSim')),
    );
    expect(container.read(showPinsProvider), isFalse);

    await tester.tap(find.byIcon(Icons.circle_outlined));
    await tester.pumpAndSettle();
    expect(container.read(showPinsProvider), isTrue);

    await tester.tap(find.byIcon(Icons.circle));
    await tester.pumpAndSettle();
    expect(container.read(showPinsProvider), isFalse);
  });

  testWidgets('industrial and minimal layouts render without overflow',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DigitalLogicSimApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('浅色精致'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工业'));
    await tester.pumpAndSettle();
    expect(find.text('DIGITAL LOGIC\nSIMULATOR'), findsOneWidget);

    // Industrial editor.
    await tester.tap(find.text('新建电路'));
    await tester.pumpAndSettle();
    expect(find.text('LOGICSIM'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('工业'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简约'));
    await tester.pumpAndSettle();
    expect(find.text('已保存的电路'), findsOneWidget);

    // Minimal editor.
    await tester.tap(find.text('新建电路'));
    await tester.pumpAndSettle();
    expect(find.text('LogicSim'), findsOneWidget);

    // Let the home screen's refresh timeout expire.
    await tester.pump(const Duration(seconds: 6));
  });
}
