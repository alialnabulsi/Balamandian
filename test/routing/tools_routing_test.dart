import 'dart:async';

import 'package:balamandian/domain/models/auth_session.dart';
import 'package:balamandian/ui/auth/widgets/session_gate_screen.dart';
import 'package:balamandian/ui/home/widgets/app_shell.dart';
import 'package:balamandian/ui/tools/widgets/tools_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../auth_test_support.dart';
import 'session_routing_test.dart' show pumpSession;

void main() {
  for (final valid in [true, false]) {
    testWidgets(
      'Public Tools retains saved-session validation gate: valid=$valid',
      (tester) async {
        final reply = Completer<http.Response>();
        final auth = AuthTestHarness((_) => reply.future);
        addTearDown(auth.close);
        auth.store.session = AuthSession.fromJson(sessionData()).session;
        await pumpSession(tester, auth, location: '/tools');
        expect(find.byType(ToolsScreen), findsNothing);
        expect(find.byType(AppShell), findsNothing);
        reply.complete(
          valid
              ? success(sessionData(), 200)
              : failure('SERVICE_UNAVAILABLE', status: 503),
        );
        await tester.pumpAndSettle();
        if (valid) {
          expect(find.byType(ToolsScreen), findsOneWidget);
        } else {
          expect(find.byType(SessionGateScreen), findsOneWidget);
          expect(find.byType(ToolsScreen), findsNothing);
          expect(auth.store.session, isNotNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
