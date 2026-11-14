import '../marketplace_test_support.dart';

import 'dart:async';

import 'package:balamandian/app.dart';
import 'package:balamandian/data/repositories/api_auth_repository.dart';
import 'package:balamandian/data/services/auth_api_service.dart';
import 'package:balamandian/data/services/session_credential_store.dart';
import 'package:balamandian/domain/models/auth_session.dart';
import 'package:balamandian/ui/auth/widgets/credentials_screen.dart';
import 'package:balamandian/ui/home/widgets/home_screen.dart';
import 'package:balamandian/ui/onboarding/widgets/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:go_router/go_router.dart';

import '../auth_test_support.dart';
import '../ui/startup_test_support.dart' show prepareAppSplash;

void main() {
  testWidgets(
    'Login, reload, Dart restart, cold launch and logout share the platform secure record',
    (tester) async {
      const storageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      const splashChannel = MethodChannel('balamandian/splash');
      final records = <String, String>{};
      final paths = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        storageChannel,
        (call) async {
          final args = call.arguments as Map;
          final key = args['key'] as String;
          switch (call.method) {
            case 'read':
              return records[key];
            case 'write':
              records[key] = args['value'] as String;
            case 'delete':
              records.remove(key);
          }
          return null;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        splashChannel,
        (_) async => null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          storageChannel,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          splashChannel,
          null,
        );
      });
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      ApiAuthRepository freshRepository() {
        final api = AuthApiService(
          client: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path.endsWith('/logout')) {
              return http.Response('', 204);
            }
            return success(sessionData(), 200);
          }),
          baseUrl: Uri.parse('https://api.example.test'),
        );
        addTearDown(api.close);
        final repository = ApiAuthRepository(
          api: api,
          credentials: const SecureSessionCredentialStore(),
        );
        addTearDown(repository.dispose);
        return repository;
      }

      var repository = freshRepository();
      await tester.pumpWidget(
        MainApp(
          marketplaceRepository: FakeMarketplaceRepository(),
          externalUrls: FakeExternalUrlService(),
          authRepository: repository,
          onboardingRepository: testOnboardingRepository(),
          initialLocation: '/welcome/sign-in',
        ),
      );
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      expect(find.byType(CredentialsScreen), findsOneWidget);
      await repository.login('FICTION001', 'test');
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(records.keys, [SecureSessionCredentialStore.storageKey]);

      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      router.go('/market');
      await tester.pumpAndSettle();
      final reassembled = tester.binding.reassembleApplication();
      await tester.pump();
      await reassembled;
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/market');
      expect(paths, ['/api/v1/auth/login']);

      // Both Dart hot restart and a new process lose the entire repository and
      // router. Only the platform record survives, not a preauthenticated fake.
      for (var launch = 0; launch < 2; launch++) {
        await tester.pumpWidget(const SizedBox.shrink());
        repository = freshRepository();
        await tester.pumpWidget(
          MainApp(
            marketplaceRepository: FakeMarketplaceRepository(),
            externalUrls: FakeExternalUrlService(),
            authRepository: repository,
            onboardingRepository: testOnboardingRepository(),
          ),
        );
        await prepareAppSplash(tester);
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(paths.where((path) => path.endsWith('/me')).length, launch + 1);
      }

      await repository.logout();
      await tester.pumpAndSettle();
      expect(records, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      repository = freshRepository();
      await tester.pumpWidget(
        MainApp(
          marketplaceRepository: FakeMarketplaceRepository(),
          externalUrls: FakeExternalUrlService(),
          authRepository: repository,
          onboardingRepository: testOnboardingRepository(),
          holdSplash: true,
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(repository.status, SessionStatus.unauthenticated);
      expect(paths.where((path) => path.endsWith('/me')).length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Pending /me times out to visible recovery, keeps token, and retries to Home',
    (tester) async {
      var calls = 0;
      final harness = AuthTestHarness((_) {
        if (++calls == 1) return Completer<http.Response>().future;
        return Future.value(success(sessionData(), 200));
      }, timeout: const Duration(seconds: 1));
      addTearDown(harness.close);
      harness.store.session = AuthSession.fromJson(sessionData()).session;
      const channel = MethodChannel('balamandian/splash');
      var revealed = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'reveal') revealed = true;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MainApp(
          marketplaceRepository: FakeMarketplaceRepository(),
          externalUrls: FakeExternalUrlService(),
          authRepository: harness.repository,
          onboardingRepository: testOnboardingRepository(),
        ),
      );
      await tester.pump();
      await prepareAppSplash(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(revealed, isTrue);
      expect(find.text('Retry'), findsOneWidget);
      expect(harness.store.session, isNotNull);
      expect(harness.store.deletes, 0);
      await tester.tap(find.text('Retry'));
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Stored-token startup releases native splash before /me completes',
    (tester) async {
      final reply = Completer<http.Response>();
      final harness = AuthTestHarness((_) => reply.future);
      addTearDown(harness.close);
      harness.store.session = AuthSession.fromJson(sessionData()).session;
      const channel = MethodChannel('balamandian/splash');
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      await tester.pumpWidget(
        MainApp(
          marketplaceRepository: FakeMarketplaceRepository(),
          externalUrls: FakeExternalUrlService(),
          authRepository: harness.repository,
          onboardingRepository: testOnboardingRepository(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump();
      await tester.pump();

      // Existing tests asserted Flutter's route but never whether Android's
      // retained overlay had actually been told to uncover that route.
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(calls, contains('reveal'));

      reply.complete(success(sessionData(), 200));
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Immediate stored-token validation still releases the native overlay',
    (tester) async {
      final harness = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(harness.close);
      harness.store.session = AuthSession.fromJson(sessionData()).session;
      const channel = MethodChannel('balamandian/splash');
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MainApp(
          marketplaceRepository: FakeMarketplaceRepository(),
          externalUrls: FakeExternalUrlService(),
          authRepository: harness.repository,
          onboardingRepository: testOnboardingRepository(),
        ),
      );
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(calls, contains('reveal'));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
