import 'dart:async';

import 'package:balamandian/domain/models/marketplace_models.dart';
import 'package:balamandian/ui/marketplace/widgets/marketplace_screen.dart';
import 'package:balamandian/ui/marketplace/widgets/marketplace_loading_state.dart';
import 'package:balamandian/ui/marketplace/widgets/marketplace_filter_sheet.dart';
import 'package:balamandian/ui/marketplace/widgets/marketplace_place_card.dart';
import 'package:balamandian/ui/marketplace/widgets/marketplace_post_card.dart';
import 'package:balamandian/ui/marketplace/widgets/marketplace_image.dart';
import 'package:balamandian/ui/marketplace/widgets/marketplace_star_input.dart';
import 'package:balamandian/ui/marketplace/widgets/place_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../marketplace_test_support.dart';
import '../marketplace_widget_support.dart';

void main() {
  testWidgets(
    'marketplace search is independent of global Search and filter sheet refreshes categories',
    (tester) async {
      final repo = FakeMarketplaceRepository(populated: true);
      await pumpMarketplace(tester, repository: repo);
      expect(find.byType(MarketplaceScreen), findsOneWidget);
      expect(find.byType(MarketplacePlaceCard), findsNWidgets(2));
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Search')),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search'));
      await tester.pump();
      expect(find.text('Search is coming soon.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'No match');
      await tester.pump(const Duration(milliseconds: 351));
      await tester.pumpAndSettle();
      expect(find.text('No places match your search'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Clear marketplace search')),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear marketplace search'));
      await tester.pump(const Duration(milliseconds: 351));
      await tester.pumpAndSettle();
      expect(find.byType(MarketplacePlaceCard), findsNWidgets(2));
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Filter marketplace categories')),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter marketplace categories'));
      await tester.pumpAndSettle();
      expect(find.byType(MarketplaceFilterSheet), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('Food & dining').last),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food & dining').last);
      await Scrollable.ensureVisible(
        tester.element(find.text('Show places')),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show places'));
      await tester.pumpAndSettle();
      expect(repo.placeQueries.last.category, 'fictional-food');
      expect(find.text('No places in this category'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('empty marketplace, no posts, first-load error and retry', (
    tester,
  ) async {
    final repo = FakeMarketplaceRepository();
    await pumpMarketplace(tester, repository: repo);
    expect(find.text('No places yet'), findsOneWidget);
    expect(find.byType(MarketplacePostCard), findsNothing);
    repo.readFailure = const MarketplaceFailure(
      'NETWORK_ERROR',
      'Offline safely.',
    );
    marketplaceRouter(tester).go('/market/$marketPlaceId');
    await tester.pumpAndSettle();
    expect(find.text('Offline safely.'), findsOneWidget);
    repo.readFailure = null;
    await Scrollable.ensureVisible(
      tester.element(find.text('Retry marketplace')),
      alignment: .35,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry marketplace'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceDetailScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'place favorite and confirmed rating controls render pending, success, replacement and removal',
    (tester) async {
      final repo = FakeMarketplaceRepository(populated: true);
      await pumpMarketplace(tester, repository: repo);
      await Scrollable.ensureVisible(
        tester.element(
          find.byTooltip('Save Fictional Coffee House to favorites'),
        ),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(
          find.byTooltip('Save Fictional Coffee House to favorites'),
        ),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Save Fictional Coffee House to favorites'),
      );
      await tester.pumpAndSettle();
      expect(repo.favoriteCalls, 1);
      expect(
        find.byTooltip('Remove Fictional Coffee House from favorites'),
        findsOneWidget,
      );
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
      expect(find.byType(PlaceDetailScreen), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.byType(MarketplaceStarInput)),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Rate 4 out of 5 stars')),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rate 4 out of 5 stars'));
      await tester.pumpAndSettle();
      expect(repo.detail.place.myRating, 4);
      expect(find.text('Your rating was saved.'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Rate 5 out of 5 stars')),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Rate 5 out of 5 stars')),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rate 5 out of 5 stars'));
      await tester.pumpAndSettle();
      expect(repo.detail.place.myRating, 5);
      await Scrollable.ensureVisible(
        tester.element(find.text('Remove my rating')),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Remove my rating')),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove my rating'));
      await tester.pumpAndSettle();
      expect(repo.detail.place.myRating, isNull);
      expect(find.text('Your rating was removed.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'posts open their place and location actions safely handle external-launch failure',
    (tester) async {
      final repo = FakeMarketplaceRepository(populated: true, withPosts: true);
      final urls = FakeExternalUrlService()..result = false;
      await pumpMarketplace(tester, repository: repo, external: urls);
      expect(find.text('NEWS'), findsOneWidget);
      expect(find.text('ADVERTISEMENT'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('A new seasonal selection').first),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A new seasonal selection').first);
      await tester.pumpAndSettle();
      expect(find.byType(PlaceDetailScreen), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('Open directions')),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Open directions')),
        alignment: .35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open directions'));
      await tester.pumpAndSettle();
      expect(urls.launched.single.queryParameters['query'], '34.1,35.2');
      expect(
        find.text('This link could not be opened. Please try again.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'null and failed network images use local marketplace assets and generic fallback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: Column(
                children: [
                  MarketplaceImage(
                    url: null,
                    slug: 'the-olive-coffee-house',
                    label: 'Coffee',
                  ),
                  MarketplaceImage(
                    url: 'https://example.invalid/failure.jpg',
                    slug: 'future-place',
                    label: 'Future',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MarketplaceLocalImage), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('no location capability keeps the real address non-interactive', (
    tester,
  ) async {
    final repo = FakeMarketplaceRepository(populated: true)
      ..detail = MarketplacePlaceDetail.fromJson({
        ...detailJson(),
        'latitude': null,
        'longitude': null,
        'phoneNumber': null,
        'websiteUrl': null,
        'socialUrl': null,
      });
    await pumpMarketplace(
      tester,
      repository: repo,
      location: '/market/$marketPlaceId',
    );
    expect(find.text('Open directions'), findsNothing);
    expect(find.text('Phone'), findsNothing);
    expect(find.text('42 Fictional Lane'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'initial loading, failed refresh with retained places, and user retry',
    (tester) async {
      final gate = Completer<MarketplacePage<MarketplacePlaceSummary>>();
      final repo = FakeMarketplaceRepository(populated: true)
        ..onPlaces = ((s, c, p, l) => gate.future);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MarketplaceScreen(repository: repo)),
        ),
      );
      await tester.pump();
      expect(find.byType(MarketplaceLoadingState), findsOneWidget);
      gate.complete(marketPage(repo.items));
      await tester.pumpAndSettle();
      expect(find.byType(MarketplacePlaceCard), findsNWidgets(2));
      repo.onPlaces = null;
      repo.readFailure = const MarketplaceFailure(
        'NETWORK_ERROR',
        'Offline safely.',
      );
      await tester.drag(find.byType(ListView), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.text('Offline safely.'), findsOneWidget);
      expect(find.byType(MarketplacePlaceCard), findsNWidgets(2));
      repo.readFailure = null;
      await Scrollable.ensureVisible(
        tester.element(find.text('Retry marketplace')),
        alignment: .2,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry marketplace'));
      await tester.pumpAndSettle();
      expect(find.text('Offline safely.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'pending favorites and failed ratings never show an unconfirmed value',
    (tester) async {
      final repo = FakeMarketplaceRepository(populated: true)
        ..mutationGate = Completer();
      await pumpMarketplace(tester, repository: repo);
      final favorite = find.byTooltip(
        'Save Fictional Coffee House to favorites',
      );
      await Scrollable.ensureVisible(tester.element(favorite), alignment: .3);
      await tester.pumpAndSettle();
      await tester.tap(favorite);
      await tester.pump();
      expect(
        find.byTooltip('Updating favorite for Fictional Coffee House'),
        findsOneWidget,
      );
      expect(repo.items.first.isFavorite, isFalse);
      repo.mutationGate!.complete();
      await tester.pumpAndSettle();
      marketplaceRouter(tester).go('/market/$marketPlaceId');
      await tester.pumpAndSettle();
      repo.mutationFailure = const MarketplaceFailure(
        'RATE_LIMITED',
        'Please wait.',
      );
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Rate 3 out of 5 stars')),
        alignment: .3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rate 3 out of 5 stars'));
      await tester.pumpAndSettle();
      expect(repo.detail.place.myRating, isNull);
      expect(find.text('Please wait.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
