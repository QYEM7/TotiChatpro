import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/core/app_config.dart';
import 'package:totichat/main.dart';

void main() {
  testWidgets('TotiChat never fakes authentication when setup is missing', (tester) async {
    await tester.pumpWidget(const TotiChatApp(configured: false));
    expect(find.textContaining('Staging setup required'), findsOneWidget);
    expect(AppConfig.isStaging, isTrue);
  });
}
