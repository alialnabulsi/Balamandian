import 'dart:convert';

import 'package:balamandian/data/repositories/lost_found_repository.dart';
import 'package:balamandian/data/services/tools_api_service.dart';
import 'package:balamandian/ui/calendar/view_models/calendar_reminder_coordinator.dart';
import 'package:balamandian/ui/calendar/widgets/campus_calendar_screen.dart';
import 'package:balamandian/ui/lost_found/widgets/lost_found_screen.dart';
import 'package:balamandian/ui/scheduler/widgets/scheduler_screen.dart';
import 'package:balamandian/ui/tools/view_models/tool_session.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/core/ui/backgrounds/app_branded_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth_test_support.dart';
import '../profile_test_support.dart';
import '../marketplace_test_support.dart';
import '../notes_test_support.dart';
import 'calendar/calendar_test.dart'
    show FakeCalendarRepository, FakeCalendarDevice;
import 'scheduler/scheduler_test.dart' show FakeSchedulerRepository;
import 'tools/tools_hub_view_model_test.dart' show setRoles;
import 'tools/tools_screen_test.dart' show captureTools;
import 'home/home_shell_test.dart' show loadHomeFonts;

void main() {
  setUpAll(loadHomeFonts);
  for (final tool in ['lost-found', 'calendar', 'scheduler']) {
    for (final size in [const Size(320, 640), const Size(844, 390)]) {
      testWidgets('$tool at $size with 2x text and dark theme', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final auth = AuthTestHarness((_) async => success(sessionData(), 200));
        addTearDown(auth.close);
        await auth.repository.login('FIRST', 'test');
        final profiles = FakeProfileRepository();
        addTearDown(profiles.dispose);
        setRoles(profiles, ['student']);
        await profiles.loadOwn();
        final calendar = FakeCalendarRepository(),
            device = FakeCalendarDevice();
        final session = ToolSession(
          auth: auth.repository,
          profiles: profiles,
          cancelPending: calendar.cancelPending,
        );
        final sync = CalendarReminderCoordinator(session, calendar, device);
        addTearDown(session.dispose);
        addTearDown(sync.dispose);
        final lostApi = ToolsApiService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'data': {
                  'items': [
                    {
                      'id': noteId,
                      'type': 'lost',
                      'title': 'A report with a longer identifying title',
                      'description': null,
                      'status': 'under_review',
                      'createdAt': '2026-11-26T10:00:00Z',
                    },
                  ],
                  'hasMore': false,
                },
              }),
              200,
            ),
          ),
          baseUrl: Uri.parse('https://example.test'),
          feature: 'lost-found',
        );
        addTearDown(lostApi.close);
        final Widget screen = switch (tool) {
          'lost-found' => LostFoundScreen(
            auth: auth.repository,
            profiles: profiles,
            repository: ApiLostFoundRepository(
              lostApi,
              auth.repository.withSession,
            ),
            files: FakeNoteFiles(),
          ),
          'calendar' => CampusCalendarScreen(
            repository: calendar,
            session: session,
            reminders: sync,
            externalUrls: FakeExternalUrlService(),
          ),
          _ => SchedulerScreen(
            auth: auth.repository,
            profiles: profiles,
            repository: FakeSchedulerRepository(),
            externalUrls: FakeExternalUrlService(),
          ),
        };
        await tester.pumpWidget(
          RepaintBoundary(
            child: MaterialApp(
              theme: appDarkTheme,
              home: AppBrandedBackground(
                child: Scaffold(body: SafeArea(child: screen)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (tool == 'lost-found') {
          await tester.ensureVisible(find.text('My reports'));
          await tester.tap(find.text('My reports'));
          await tester.pumpAndSettle();
        }
        if (tool == 'scheduler') {
          await tester.tap(find.text('Create a schedule'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byType(CheckboxListTile),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await captureTools(
          tester,
          'remaining-$tool-${size.width.toInt()}-2x',
          size,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
