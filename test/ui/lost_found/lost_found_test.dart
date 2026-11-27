import 'dart:async';
import 'dart:convert';

import 'package:balamandian/data/repositories/lost_found_repository.dart';
import 'package:balamandian/data/services/tools_api_service.dart';
import 'package:balamandian/ui/tools/view_models/tool_session.dart';
import 'package:balamandian/ui/lost_found/view_models/lost_found_view_model.dart';
import 'package:balamandian/ui/lost_found/widgets/report_form.dart';
import 'package:balamandian/domain/models/tool_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../auth_test_support.dart';
import '../../profile_test_support.dart';
import '../../notes_test_support.dart';
import '../tools/tools_hub_view_model_test.dart' show setRoles;
import '../home/home_shell_test.dart' show loadHomeFonts;

Map<String, Object?> report() => {
  'id': noteId,
  'type': 'found',
  'title': 'Keys',
  'status': 'submitted',
  'description': null,
  'createdAt': '2026-11-26T10:00:00Z',
};
void main() {
  setUpAll(loadHomeFonts);
  test('private API mapping, title-only creation, retry key, withdrawal and session isolation', () async {
    final auth = AuthTestHarness(
      (q) async => q.url.path.endsWith('/logout')
          ? http.Response('', 204)
          : success(sessionData(), 200),
    );
    addTearDown(auth.close);
    await auth.repository.login('FIRST', 'test');
    final profiles = FakeProfileRepository();
    addTearDown(profiles.dispose);
    setRoles(profiles, ['staff', 'advisor']);
    await profiles.loadOwn();
    Completer<http.Response>? late;
    var calls = 0;
    final client = MockClient((q) async {
      calls++;
      expect(q.headers['Authorization'], isNotNull);
      expect(q.url.path, startsWith('/api/v1/lost-found'));
      if (late != null) return late.future;
      if (q.method == 'POST' && q.url.path.endsWith('/lost-found')) {
        final j = jsonDecode(q.body) as Map;
        expect(j['description'], isNull);
        expect(j['submissionKey'], 'a' * 32);
        return http.Response(jsonEncode({'data': report()}), 201);
      }
      if (q.url.path.endsWith('/withdraw')) {
        return http.Response(
          jsonEncode({
            'data': {...report(), 'status': 'withdrawn'},
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'data': {
            'items': [report()],
            'hasMore': false,
          },
        }),
        200,
      );
    });
    final api = ToolsApiService(
      client: client,
      baseUrl: Uri.parse('https://example.test'),
      feature: 'lost-found',
    );
    addTearDown(api.close);
    final repo = ApiLostFoundRepository(api, auth.repository.withSession);
    final session = ToolSession(
      auth: auth.repository,
      profiles: profiles,
      cancelPending: repo.cancelPending,
    );
    addTearDown(session.dispose);
    expect(session.access, ToolAccess.eligible);
    final created = await repo.submit(
      key: 'a' * 32,
      type: 'found',
      title: 'Keys',
      uploads: [],
    );
    expect(created.description, isNull);
    final model = LostFoundViewModel(session, repo);
    addTearDown(model.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(model.reports.single.title, 'Keys');
    expect(await model.withdraw(noteId), isTrue);
    late = Completer<http.Response>();
    final pending = model.load();
    await Future<void>.delayed(Duration.zero);
    await auth.repository.logout();
    late.complete(
      http.Response(
        jsonEncode({
          'data': {
            'items': [report()],
            'hasMore': false,
          },
        }),
        200,
      ),
    );
    await pending;
    expect(model.reports, isEmpty);
    expect(session.owner, isNull);
    expect(calls, greaterThan(2));
  });
  for (final roles in [
    <String>[],
    ['staff'],
    ['instructor'],
  ]) {
    test('ineligible $roles never reads reports', () async {
      final auth = AuthTestHarness(
        (q) async => q.url.path.endsWith('/logout')
            ? http.Response('', 204)
            : success(sessionData(), 200),
      );
      addTearDown(auth.close);
      await auth.repository.login('FIRST', 'test');
      final profiles = FakeProfileRepository();
      addTearDown(profiles.dispose);
      setRoles(profiles, roles);
      await profiles.loadOwn();
      final api = ToolsApiService(
        client: MockClient(
          (_) async => throw StateError('Private call forbidden'),
        ),
        baseUrl: Uri.parse('https://example.test'),
        feature: 'lost-found',
      );
      addTearDown(api.close);
      final repo = ApiLostFoundRepository(api, auth.repository.withSession);
      final session = ToolSession(
        auth: auth.repository,
        profiles: profiles,
        cancelPending: repo.cancelPending,
      );
      addTearDown(session.dispose);
      final model = LostFoundViewModel(session, repo);
      addTearDown(model.dispose);
      expect(session.access, ToolAccess.ineligible);
      expect(model.reports, isEmpty);
    });
  }
  testWidgets(
    'keyboard-safe title-only form retains content and key on failed submission',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.reset);
      final auth = AuthTestHarness(
        (q) async => q.url.path.endsWith('/logout')
            ? http.Response('', 204)
            : success(sessionData(), 200),
      );
      addTearDown(auth.close);
      await auth.repository.login('FIRST', 'test');
      final profiles = FakeProfileRepository();
      addTearDown(profiles.dispose);
      setRoles(profiles, ['student']);
      await profiles.loadOwn();
      String? key;
      var attempts = 0;
      final api = ToolsApiService(
        client: MockClient((q) async {
          attempts++;
          final j = jsonDecode(q.body) as Map;
          key ??= j['submissionKey'] as String;
          expect(j['submissionKey'], key);
          expect(j['uploadIds'], isEmpty);
          return http.Response(
            jsonEncode({
              'error': {'code': 'INTERNAL_ERROR'},
            }),
            500,
          );
        }),
        baseUrl: Uri.parse('https://example.test'),
        feature: 'lost-found',
      );
      addTearDown(api.close);
      final repo = ApiLostFoundRepository(api, auth.repository.withSession);
      final session = ToolSession(
        auth: auth.repository,
        profiles: profiles,
        cancelPending: repo.cancelPending,
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportForm(
              type: 'lost',
              repository: repo,
              files: FakeNoteFiles(),
              session: session,
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'A private title',
      );
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();
      expect(find.text('A private title'), findsOneWidget);
      expect(find.text(ToolFailure.fromCode(null).message), findsOneWidget);
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
