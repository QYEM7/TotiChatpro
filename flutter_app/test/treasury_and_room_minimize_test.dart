import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  test('treasury coins are parsed exactly without floating point rounding', () {
    expect(TotiChatServices.parseTreasuryAmount('1'), 1);
    expect(TotiChatServices.parseTreasuryAmount(' 7000 '), 7000);
    expect(TotiChatServices.parseTreasuryAmount('9007199254740991'),
        9007199254740991);
    for (final invalid in [
      '', '0', '-1', '01', '1.5', '1e6', '1,000',
      '9007199254740992', '999999999999999999999999',
    ]) {
      expect(TotiChatServices.parseTreasuryAmount(invalid), isNull,
        reason: 'Invalid financial amount: $invalid');
    }
  });

  testWidgets('kept-alive offstage room state survives minimization',
      (tester) async {
    var initializations = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Offstage(
      offstage: false,
      child: _KeepAliveProbe(onInitialize: () => initializations++),
    ))));
    expect(initializations, 1);
    expect(find.text('session active'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Offstage(
      offstage: true,
      child: _KeepAliveProbe(onInitialize: () => initializations++),
    ))));
    expect(initializations, 1);
    expect(find.text('session active'), findsNothing);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Offstage(
      offstage: false,
      child: _KeepAliveProbe(onInitialize: () => initializations++),
    ))));
    expect(initializations, 1);
    expect(find.text('session active'), findsOneWidget);
  });
}

class _KeepAliveProbe extends StatefulWidget {
  const _KeepAliveProbe({required this.onInitialize});
  final VoidCallback onInitialize;

  @override
  State<_KeepAliveProbe> createState() => _KeepAliveProbeState();
}

class _KeepAliveProbeState extends State<_KeepAliveProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInitialize();
  }

  @override
  Widget build(BuildContext context) =>
      const Text('session active');
}
