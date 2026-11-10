import 'dart:async';

import 'package:balamandian/app.dart';
import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:balamandian/domain/models/auth_session.dart';
import 'package:balamandian/ui/auth/widgets/credentials_screen.dart';
import 'package:balamandian/ui/auth/widgets/logout_dialog.dart';
import 'package:balamandian/ui/auth/widgets/session_gate_screen.dart';
import 'package:balamandian/ui/core/ui/buttons/drawer_logout_button.dart';
import 'package:balamandian/ui/core/ui/action_button.dart';
import 'package:balamandian/ui/home/widgets/app_shell.dart';
import 'package:balamandian/ui/home/widgets/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../auth_test_support.dart';
import '../ui/startup_test_support.dart';

Future<void> pumpSession(
  WidgetTester tester,
  AuthTestHarness h, {
  String location = '/welcome/splash',
}) async {
  mockNativeSplash(tester);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    MainApp(authRepository: h.repository, initialLocation: location),
  );
  await tester.pump();
}

Future<void> openLogout(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open account menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DrawerLogoutButton));
  await tester.pumpAndSettle();
}

Future<void> confirmLogout(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(LogoutDialog),
      matching: find.text('Log out'),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadStartupFonts);

  testWidgets('Login after logout starts a fresh shell with the new identity', (
    tester,
  ) async {
    var logins = 0;
    final h = AuthTestHarness((request) async {
      if (request.url.path.endsWith('/logout')) return http.Response('', 204);
      final data = sessionData();
      if (++logins > 1) {
        data['user'] = {
          ...data['user'] as Map,
          'sisUserId': 'FICTION002',
          'institutionalEmail': 'second@example.edu',
        };
      }
      return success(data, 200);
    });
    addTearDown(h.close);
    await pumpSession(tester, h, location: '/welcome/sign-in');
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.enterText(find.byType(TextField).first, 'FICTION00${i + 1}');
      await tester.enterText(find.byType(TextField).last, 'test');
      await tester.tap(find.byType(ActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      final router = GoRouter.of(tester.element(find.byType(AppShell)));
      expect(router.routeInformationProvider.value.uri.path, '/');
      if (i == 0) {
        router.go('/profile');
        await tester.pumpAndSettle();
        await openLogout(tester);
        await confirmLogout(tester);
        await tester.pumpAndSettle();
        expect(find.byType(CredentialsScreen), findsOneWidget);
      }
    }
    await tester.tap(find.byTooltip('Open account menu'));
    await tester.pumpAndSettle();
    expect(find.text('second@example.edu'), findsOneWidget);
    expect(find.text('SIS ID: FICTION002'), findsOneWidget);
    expect(find.text('member@example.edu'), findsNothing);
    expect(h.store.writes, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Every protected route redirects unauthenticated users to Login',
    (tester) async {
      final h = AuthTestHarness((_) async => fail('No request expected'));
      addTearDown(h.close);
      await pumpSession(tester, h, location: '/settings');
      await tester.pumpAndSettle();
      final router = GoRouter.of(
        tester.element(find.byType(CredentialsScreen)),
      );
      for (final path in [
        '/',
        '/map',
        '/market',
        '/profile',
        '/guide',
        '/ai',
        '/tools',
        '/settings',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/welcome/sign-in',
        );
        expect(find.byType(AppShell), findsNothing);
      }
      router.go('/welcome/sign-up');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CredentialsScreen>(find.byType(CredentialsScreen))
            .signingUp,
        isTrue,
      );
      router.go('/welcome/verify-email');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/welcome/verify-email',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Validation blocks protected content, restores Home once, survives rebuilds',
    (tester) async {
      var calls = 0;
      final reply = Completer<http.Response>();
      final h = AuthTestHarness((_) {
        calls++;
        return reply.future;
      });
      addTearDown(h.close);
      h.store.session = AuthSession.fromJson(sessionData()).session;
      final key = GlobalKey();
      mockNativeSplash(tester);
      await tester.pumpWidget(MainApp(key: key, authRepository: h.repository));
      await tester.pump();
      expect(find.byType(SessionGateScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(CredentialsScreen), findsNothing);
      reply.complete(success(sessionData(), 200));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      router.go('/market');
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MainApp(
          key: key,
          authRepository: h.repository,
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/market');
      expect(calls, 1);
      expect(h.store.reads, 1);
      await tester.tap(find.byTooltip('Open account menu'));
      await tester.pumpAndSettle();
      expect(find.text('member@example.edu'), findsOneWidget);
      expect(find.text('SIS ID: FICTION001'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Expired startup session reaches Login with a friendly notice', (
    tester,
  ) async {
    final h = AuthTestHarness(
      (_) async => failure('UNAUTHENTICATED', status: 401),
    );
    addTearDown(h.close);
    h.store.session = AuthSession.fromJson(sessionData()).session;
    await pumpSession(tester, h);
    await tester.pumpAndSettle();
    expect(find.byType(CredentialsScreen), findsOneWidget);
    expect(
      find.text('Your session has expired. Please log in again.'),
      findsOneWidget,
    );
    expect(h.store.session, isNull);
    expect(find.byType(AppShell), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Offline startup offers Retry and preserves credentials until validation',
    (tester) async {
      var calls = 0;
      final h = AuthTestHarness((_) async {
        if (++calls == 1) throw http.ClientException('offline');
        return success(sessionData(), 200);
      });
      addTearDown(h.close);
      h.store.session = AuthSession.fromJson(sessionData()).session;
      await pumpSession(tester, h);
      await tester.pumpAndSettle();
      expect(find.byType(SessionGateScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(h.store.session, isNotNull);
      expect(find.text('Sign out on this device'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(calls, 2);
      expect(h.store.deletes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Offline startup allows explicit device-only sign-out', (
    tester,
  ) async {
    var calls = 0;
    final h = AuthTestHarness((_) async {
      calls++;
      throw http.ClientException('offline');
    });
    addTearDown(h.close);
    h.store.session = AuthSession.fromJson(sessionData()).session;
    await pumpSession(tester, h);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out on this device'));
    await tester.pumpAndSettle();
    expect(find.byType(CredentialsScreen), findsOneWidget);
    expect(h.store.session, isNull);
    expect(calls, 1);
    expect(h.repository.user, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Logout confirms, blocks duplicates, clears all protected navigation and Back',
    (tester) async {
      final logout = Completer<http.Response>();
      var calls = 0;
      final h = AuthTestHarness((request) async {
        if (request.url.path.endsWith('/me')) {
          return success(sessionData(), 200);
        }
        calls++;
        return logout.future;
      });
      addTearDown(h.close);
      h.store.session = AuthSession.fromJson(sessionData()).session;
      await pumpSession(tester, h);
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(AppShell)));
      router.go('/map');
      await tester.pumpAndSettle();
      unawaited(router.push<void>('/settings'));
      await tester.pumpAndSettle();
      await openLogout(tester);
      expect(find.text('Log out?'), findsOneWidget);
      expect(
        find.text('Are you sure you want to log out of Balamandian?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await openLogout(tester);
      await confirmLogout(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(h.store.deletes, 0);
      logout.complete(http.Response('', 204));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/welcome/sign-in',
      );
      expect(router.canPop(), isFalse);
      expect(find.byType(AppShell), findsNothing);
      expect(find.text('member@example.edu'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsNothing);
      router.go('/map');
      await tester.pumpAndSettle();
      expect(find.byType(CredentialsScreen), findsOneWidget);
      expect(h.store.session, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Logout failure offers Retry and device-only recovery', (
    tester,
  ) async {
    var calls = 0;
    final h = AuthTestHarness((request) async {
      if (request.url.path.endsWith('/me')) return success(sessionData(), 200);
      calls++;
      throw http.ClientException('offline');
    });
    addTearDown(h.close);
    h.store.session = AuthSession.fromJson(sessionData()).session;
    await pumpSession(tester, h);
    await tester.pumpAndSettle();
    await openLogout(tester);
    await confirmLogout(tester);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Server sign-out could not be confirmed'),
      findsOneWidget,
    );
    expect(h.store.session, isNotNull);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.tap(find.text('Sign out on this device'));
    await tester.pumpAndSettle();
    expect(find.byType(CredentialsScreen), findsOneWidget);
    expect(find.byType(LogoutDialog), findsNothing);
    expect(h.store.session, isNull);
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Deletion failure removes identity, blocks shell, and offers cleanup retry',
    (tester) async {
      final h = AuthTestHarness(
        (request) async => request.url.path.endsWith('/me')
            ? success(sessionData(), 200)
            : http.Response('', 204),
      );
      addTearDown(h.close);
      h.store.session = AuthSession.fromJson(sessionData()).session;
      h.store.failDelete = true;
      await pumpSession(tester, h);
      await tester.pumpAndSettle();
      await openLogout(tester);
      await confirmLogout(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SessionGateScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(h.repository.user, isNull);
      expect(h.store.session, isNotNull);
      h.store.failDelete = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(CredentialsScreen), findsOneWidget);
      expect(h.store.session, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Protected 401 removes the active shell and redirects to Login', (
    tester,
  ) async {
    final h = AuthTestHarness((_) async => success(sessionData(), 200));
    addTearDown(h.close);
    h.store.session = AuthSession.fromJson(sessionData()).session;
    await pumpSession(tester, h);
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(AppShell)));
    router.go('/profile');
    await tester.pumpAndSettle();
    await openLogout(tester);
    await expectLater(
      h.repository.withSession<void>(
        (_) async =>
            throw AuthFailure.fromApi('UNAUTHENTICATED', statusCode: 401),
      ),
      throwsA(isA<AuthFailure>()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CredentialsScreen), findsOneWidget);
    expect(
      find.text('Your session has expired. Please log in again.'),
      findsOneWidget,
    );
    expect(find.byType(AppShell), findsNothing);
    expect(find.byType(LogoutDialog), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
