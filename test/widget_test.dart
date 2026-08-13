import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_logic_sim/app.dart';

void main() {
  testWidgets('renders the main circuit editor', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DigitalLogicSimApp(),
      ),
    );

    expect(find.text('LogicSim'), findsOneWidget);
    expect(find.text('Chip Library'), findsOneWidget);
    expect(find.text('I/O Panel'), findsOneWidget);
  });
}
