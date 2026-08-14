import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_logic_sim/app.dart';

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
    expect(find.text('输入 / 输出'), findsOneWidget);
  });

  testWidgets('theme toggle switches between light and dark mode',
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

    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
  });
}
