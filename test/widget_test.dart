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

    await tester.tap(find.text('日间工业'));
    await tester.pumpAndSettle();
    expect(find.text('选择主题'), findsOneWidget);

    await tester.tap(find.text('夜间精致'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(find.text('夜间精致'), findsOneWidget);
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
    expect(container.read(chipStyleProvider), ChipStyle.industrial);
    expect(container.read(showPinsProvider), isTrue);

    // Open the theme picker from the editor header and pick night + refined.
    await tester.tap(find.byTooltip('主题：日间工业'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('夜间精致'));
    await tester.pumpAndSettle();

    expect(container.read(chipStyleProvider), ChipStyle.refined);
    expect(container.read(showPinsProvider), isFalse);
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
    expect(container.read(showPinsProvider), isTrue);

    await tester.tap(find.byIcon(Icons.circle));
    await tester.pumpAndSettle();
    expect(container.read(showPinsProvider), isFalse);

    await tester.tap(find.byIcon(Icons.circle_outlined));
    await tester.pumpAndSettle();
    expect(container.read(showPinsProvider), isTrue);
  });
}
