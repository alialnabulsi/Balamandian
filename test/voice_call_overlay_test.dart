import 'package:balamandian/data/repositories/messaging_repository.dart';
import 'package:balamandian/data/repositories/profile_repository.dart';
import 'package:balamandian/domain/models/calling.dart';
import 'package:balamandian/ui/messaging/view_models/calling_session.dart';
import 'package:balamandian/ui/messaging/view_models/messaging_session.dart';
import 'package:balamandian/ui/messaging/widgets/messaging_scope.dart';
import 'package:balamandian/ui/messaging/widgets/voice_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('incoming calls render and minimize above the navigator', (
    tester,
  ) async {
    final messaging = _IdleMessaging();
    final calls = CallingSession(_UnusedMessagingRepository())
      ..call = VoiceCall({
        'id': 'call',
        'conversationId': 'conversation',
        'kind': 'group',
        'title': 'Campus Photo Walk',
        'state': 'invited',
        'epoch': 'epoch',
      });
    addTearDown(calls.dispose);
    addTearDown(messaging.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MessagingScope(
          session: messaging,
          profiles: _UnusedProfileRepository(),
          child: CallingHost(calls: calls, child: child!),
        ),
        home: const Scaffold(body: Text('Inbox')),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Accept'), findsOneWidget);
    expect(find.text('Incoming voice call'), findsOneWidget);

    await tester.tap(find.byTooltip('Minimize voice call'));
    await tester.pump();
    expect(find.byTooltip('Accept'), findsNothing);
    await tester.tap(find.text('Campus Photo Walk'));
    await tester.pump();
    expect(find.byTooltip('Accept'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _IdleMessaging extends ChangeNotifier implements MessagingSession {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedMessagingRepository implements MessagingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
