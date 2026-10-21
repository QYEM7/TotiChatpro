import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/core/green_theme.dart';
import 'package:totichat/src/core/premium_ui.dart';

void main() {
  testWidgets('premium empty states render without mocked entities', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: GreenTheme.light,
      home: const Scaffold(body: PremiumEmptyState(
        icon: Icons.headphones,
        title: 'Empty',
        subtitle: 'Only actual data',
      )),
    ));
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('Only actual data'), findsOneWidget);
    expect(find.byIcon(Icons.headphones), findsOneWidget);
  });

  testWidgets('premium navigation action is wired', (tester) async {
    var invoked = false;
    await tester.pumpWidget(MaterialApp(theme: GreenTheme.light,
      home: Scaffold(body: PremiumRow(
        icon: Icons.storefront_outlined,
        title: 'Store',
        onTap: () { invoked = true; },
      )),
    ));
    await tester.tap(find.text('Store'));
    expect(invoked, isTrue);
  });

  testWidgets('mint page uses approved light palette', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: GreenTheme.light,
      home: const PremiumPage(title: 'TotiChat', body: Text('Ready')),
    ));
    expect(find.text('TotiChat'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, GreenTheme.background);
  });
}
