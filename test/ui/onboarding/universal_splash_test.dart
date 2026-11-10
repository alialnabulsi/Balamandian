import 'dart:async';

import 'package:balamandian/app.dart';
import 'package:balamandian/data/repositories/onboarding_repository.dart';
import 'package:balamandian/domain/models/auth_session.dart';
import 'package:balamandian/ui/auth/widgets/credentials_screen.dart';
import 'package:balamandian/ui/auth/widgets/getting_started_screen.dart';
import 'package:balamandian/ui/auth/widgets/session_gate_screen.dart';
import 'package:balamandian/ui/home/widgets/home_screen.dart';
import 'package:balamandian/ui/onboarding/widgets/splash_loading_logo.dart';
import 'package:balamandian/ui/onboarding/widgets/splash_screen.dart';
import 'package:balamandian/ui/onboarding/widgets/tour_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../auth_test_support.dart';
import '../startup_test_support.dart';

double stroke(WidgetTester tester) => tester
    .widget<SplashLoadingLogo>(find.byType(SplashLoadingLogo))
    .progress
    .value;

Future<void> startEntry(
  WidgetTester tester,
  AuthTestHarness h, {
  OnboardingRepository? onboarding,
}) async {
  mockNativeSplash(tester);
  await tester.pumpWidget(
    MainApp(
      authRepository: h.repository,
      onboardingRepository: onboarding ?? testOnboardingRepository(),
    ),
  );
  await prepareAppSplash(tester);
  expect(find.byType(SplashScreen), findsOneWidget);
  expect(stroke(tester), 0);
}

void background(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void foreground(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

Future<void> finishEntryAnimation(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
  await advanceTransition(tester);
}

void main() {
  setUpAll(loadStartupFonts);

  testWidgets(
    'Preference recovery resumes first-launch onboarding without another session read',
    (tester) async {
      final preferences = MemoryOnboardingStore()..fail = true;
      final h = AuthTestHarness((_) async => fail('No request expected'));
      addTearDown(h.close);
      await startEntry(
        tester,
        h,
        onboarding: OnboardingRepository(store: preferences),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      preferences.fail = false;
      await tester.tap(find.text('Retry'));
      await advanceTransition(tester);
      expect(find.byType(TourScreen), findsOneWidget);
      expect(h.store.reads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Failed onboarding persistence stays on the tour and can be retried',
    (tester) async {
      final preferences = MemoryOnboardingStore();
      final h = AuthTestHarness((_) async => fail('No request expected'));
      addTearDown(h.close);
      await startEntry(
        tester,
        h,
        onboarding: OnboardingRepository(store: preferences),
      );
      await finishEntryAnimation(tester);
      GoRouter.of(tester.element(find.byType(TourScreen)))
          .go('/welcome/assistant');
      await advanceTransition(tester);
      preferences.fail = true;
      await tester.tap(find.text('Get started'));
      await advanceTransition(tester);
      expect(find.byType(TourScreen), findsOneWidget);
      expect(
        find.textContaining('Your progress could not be saved'),
        findsOneWidget,
      );
      preferences.fail = false;
      await tester.tap(find.text('Get started'));
      await advanceTransition(tester);
      expect(find.byType(GettingStartedScreen), findsOneWidget);
      expect(preferences.completed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final returning in [false, true]) {
    testWidgets(
      '${returning ? 'Returning logged-out' : 'First'} launch plays full animation before entry',
      (tester) async {
        final h = AuthTestHarness((_) async => fail('No request expected'));
        addTearDown(h.close);
        await startEntry(
          tester,
          h,
          onboarding: testOnboardingRepository(completed: returning),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        expect(stroke(tester), inExclusiveRange(0, 1));
        expect(find.byType(TourScreen), findsNothing);
        expect(find.byType(GettingStartedScreen), findsNothing);
        await finishEntryAnimation(tester);
        expect(find.byType(SplashScreen), findsNothing);
        expect(
          returning
              ? find.byType(GettingStartedScreen)
              : find.byType(TourScreen),
          findsOneWidget,
        );
        expect(h.store.reads, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final mode in ['valid', 'expired', 'offline']) {
    testWidgets(
      'Fast $mode validation never cuts the original animation short',
      (tester) async {
        var calls = 0;
        final h = AuthTestHarness((_) async {
          calls++;
          return switch (mode) {
            'valid' => success(sessionData(), 200),
            'expired' => failure('UNAUTHENTICATED', status: 401),
            _ => throw http.ClientException('offline'),
          };
        });
        addTearDown(h.close);
        h.store.session = AuthSession.fromJson(sessionData()).session;
        await startEntry(tester, h);
        await tester.pump(const Duration(milliseconds: 1000));
        expect(find.byType(HomeScreen), findsNothing);
        expect(find.byType(CredentialsScreen), findsNothing);
        expect(find.byType(SessionGateScreen), findsNothing);
        expect(stroke(tester), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(find.byType(SplashScreen), findsNothing);
        expect(switch (mode) {
          'valid' => find.byType(HomeScreen),
          'expired' => find.byType(CredentialsScreen),
          _ => find.text('Retry'),
        }, findsOneWidget);
        expect(calls, 1);
        expect(h.store.session == null, mode == 'expired');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Slow validation holds the completed splash, then proceeds once',
    (tester) async {
      final reply = Completer<http.Response>();
      var calls = 0;
      final h = AuthTestHarness((_) {
        calls++;
        return reply.future;
      });
      addTearDown(h.close);
      h.store.session = AuthSession.fromJson(sessionData()).session;
      await startEntry(tester, h);
      final splash = tester.element(find.byType(SplashScreen));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(stroke(tester), 1);
      expect(tester.element(find.byType(SplashScreen)), same(splash));
      expect(find.byType(HomeScreen), findsNothing);
      reply.complete(success(sessionData(), 200));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Genuine re-entry replays once, retains routes, and makes no /me request',
    (tester) async {
      var calls = 0;
      final h = AuthTestHarness((_) async {
        calls++;
        return success(sessionData(), 200);
      });
      addTearDown(h.close);
      h.store.session = AuthSession.fromJson(sessionData()).session;
      await startEntry(tester, h);
      await tester.pumpAndSettle();
      final home = tester.element(find.byType(HomeScreen));
      final router = GoRouter.of(home);
      router.go('/market');
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      background(tester);
      await tester.pump();
      foreground(tester);
      await prepareAppSplash(tester);
      expect(find.byType(SplashScreen), findsOneWidget);
      final replay = tester.element(find.byType(SplashScreen));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.element(find.byType(SplashScreen)), same(replay));
      expect(router.routeInformationProvider.value.uri.path, '/market');
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('Market coming soon'), findsOneWidget);
      expect(calls, 1);
      router.go('/');
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(HomeScreen)), same(home));
      expect(find.byType(SplashScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Hot reload retains navigation; a fresh Dart root plays splash again',
    (tester) async {
      final h = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(h.close);
      h.store.session = AuthSession.fromJson(sessionData()).session;
      await startEntry(tester, h);
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      router.go('/profile');
      await tester.pumpAndSettle();
      final reassembled = tester.binding.reassembleApplication();
      await tester.pump();
      await reassembled;
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/profile');
      await tester.pumpWidget(const SizedBox.shrink());
      final restarted = AuthTestHarness(
        (_) async => success(sessionData(), 200),
      );
      addTearDown(restarted.close);
      restarted.store.session = h.store.session;
      await startEntry(tester, restarted);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(HomeScreen), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(restarted.store.reads, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Completed onboarding survives a new app root without a session',
    (tester) async {
      final preferences = MemoryOnboardingStore();
      final h = AuthTestHarness((_) async => fail('No request expected'));
      addTearDown(h.close);
      await startEntry(
        tester,
        h,
        onboarding: OnboardingRepository(store: preferences),
      );
      await finishEntryAnimation(tester);
      final router = GoRouter.of(tester.element(find.byType(TourScreen)));
      router.go('/welcome/assistant');
      await advanceTransition(tester);
      await tester.tap(find.text('Get started'));
      await advanceTransition(tester);
      expect(preferences.completed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await startEntry(
        tester,
        h,
        onboarding: OnboardingRepository(store: preferences),
      );
      await finishEntryAnimation(tester);
      expect(find.byType(GettingStartedScreen), findsOneWidget);
      expect(find.byType(TourScreen), findsNothing);
      expect(preferences.writes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
