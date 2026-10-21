import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/core/green_theme.dart';
import 'package:totichat/src/screens/login_screen.dart';

void main() {
  test('one official light-green theme across login and home', () {
    final theme = GreenTheme.light;
    expect(theme.colorScheme.primary, GreenTheme.primary);
    expect(theme.scaffoldBackgroundColor, GreenTheme.background);
    expect(theme.brightness, Brightness.light);
  });

  testWidgets('Google-only beta login renders the approved green surface',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: GreenTheme.light, home: const LoginScreen()),
    );

    final screen = tester.widget<Scaffold>(
      find.byKey(const Key('totichat-green-login')),
    );
    expect(screen.backgroundColor, GreenTheme.background);
    expect(find.text('TotiChat'), findsOneWidget);
    expect(find.byKey(const Key('totichat-google-sign-in')), findsOneWidget);
    expect(find.text('Toti Chat'), findsNothing);
    expect(find.textContaining('phone'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
