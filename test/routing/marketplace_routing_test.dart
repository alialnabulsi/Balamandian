import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:balamandian/app.dart';
import 'package:balamandian/data/repositories/api_marketplace_repository.dart';
import 'package:balamandian/data/services/marketplace_api_service.dart';
import 'package:balamandian/ui/auth/widgets/credentials_screen.dart';
import 'package:balamandian/domain/models/auth_session.dart';

import '../auth_test_support.dart';
import '../ui/startup_test_support.dart';

import 'package:go_router/go_router.dart';
import 'package:balamandian/ui/marketplace/widgets/marketplace_screen.dart';
import 'package:balamandian/ui/marketplace/widgets/place_detail_screen.dart';
import 'package:balamandian/ui/home/widgets/app_shell.dart';
import 'package:balamandian/ui/core/ui/navigation/app_navigation_item.dart';
import 'package:balamandian/ui/core/ui/navigation/app_bottom_bar.dart';
import 'package:balamandian/ui/core/ui/navigation/balamandian_top_bar.dart';
import 'package:balamandian/ui/core/ui/quick_actions/expandable_quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../marketplace_test_support.dart';
import '../ui/marketplace/marketplace_widget_support.dart';

void main() {
  testWidgets(
    'detail stays in Market shell; Android back retains search and refreshes ordering',
    (tester) async {
      final repo = FakeMarketplaceRepository(populated: true);
      await pumpMarketplace(tester, repository: repo);
      final shell = tester.element(find.byType(AppShell));
      final root = tester.element(find.byType(MarketplaceScreen));
      await tester.enterText(find.byType(TextField), 'Coffee');
      await tester.pump(const Duration(milliseconds: 351));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('View details').first),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('View details').first),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View details').first);
      await tester.pumpAndSettle();
      expect(
        GoRouterState.of(tester.element(find.byType(PlaceDetailScreen)))
            .uri
            .path,
        '/market/$marketPlaceId',
      );
      expect(find.byType(PlaceDetailScreen), findsOneWidget);
      expect(tester.element(find.byType(AppShell)), same(shell));
      for (final type in [
        AppBottomBar,
        BalamandianTopBar,
        ExpandableQuickActions,
      ]) {
        expect(find.byType(type), findsOneWidget);
      }
      expect(
        tester
            .widget<AppNavigationItem>(
              find.byWidgetPredicate(
                (w) => w is AppNavigationItem && w.label == 'Market',
              ),
            )
            .selected,
        isTrue,
      );
      expect(find.byTooltip('Create'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        marketplaceRouter(tester).routeInformationProvider.value.uri.path,
        '/market',
      );
      expect(tester.element(find.byType(MarketplaceScreen)), same(root));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Coffee',
      );
      expect(repo.placeQueries.last.search, 'Coffee');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'switching branches retains marketplace search and leaves Map/Profile unchanged',
    (tester) async {
      final repo = FakeMarketplaceRepository(populated: true);
      await pumpMarketplace(tester, repository: repo);
      await tester.enterText(find.byType(TextField), 'Coffee');
      await tester.pump(const Duration(milliseconds: 351));
      await tester.pumpAndSettle();
      for (final label in ['Map', 'Profile']) {
        await Scrollable.ensureVisible(
          tester.element(
            find.byWidgetPredicate(
              (w) => w is AppNavigationItem && w.label == label,
            ),
          ),
          alignment: .35,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is AppNavigationItem && w.label == label,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('$label coming soon'), findsOneWidget);
      }
      await Scrollable.ensureVisible(
        tester.element(
          find.byWidgetPredicate(
            (w) => w is AppNavigationItem && w.label == 'Market',
          ),
        ),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is AppNavigationItem && w.label == 'Market',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Coffee',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'marketplace 401 invalidates the session and removes protected shell routes',
    (tester) async {
      mockNativeSplash(tester);
      final auth = AuthTestHarness((_) async => success(sessionData(), 200));
      addTearDown(auth.close);
      await auth.repository.login('FICTION001', 'test');
      final service = MarketplaceApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'code': 'UNAUTHENTICATED', 'message': 'private text'},
            }),
            401,
          ),
        ),
        baseUrl: Uri.parse('https://api.example.test'),
      );
      addTearDown(service.close);
      final repo = ApiMarketplaceRepository(
        api: service,
        withSession: auth.repository.withSession,
      );
      await tester.pumpWidget(
        MainApp(
          authRepository: auth.repository,
          marketplaceRepository: repo,
          externalUrls: FakeExternalUrlService(),
          onboardingRepository: testOnboardingRepository(),
          initialLocation: '/market',
        ),
      );
      await prepareAppSplash(tester);
      await tester.pumpAndSettle();
      expect(auth.repository.status, SessionStatus.unauthenticated);
      expect(auth.store.session, isNull);
      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(CredentialsScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
