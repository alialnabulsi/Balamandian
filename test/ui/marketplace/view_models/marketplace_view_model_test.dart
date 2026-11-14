import 'dart:async';

import 'package:balamandian/domain/models/marketplace_models.dart';
import 'package:balamandian/domain/models/auth_failure.dart';
import 'package:balamandian/ui/marketplace/view_models/marketplace_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../marketplace_test_support.dart';

void main() {
  test(
    'initial attachment loads once and exposes immutable renderable state',
    () async {
      final repo = FakeMarketplaceRepository(populated: true),
          vm = MarketplaceViewModel(repository: FakeMarketplaceRepository());
      vm.dispose();
      await vm.initialize();
      final model = MarketplaceViewModel(repository: repo);
      addTearDown(model.dispose);
      expect(model.state.loading, isTrue);
      await model.initialize();
      await model.initialize();
      expect(repo.placeCalls, 1);
      expect(repo.categoryCalls, 1);
      expect(model.state.places.length, 2);
      expect(() => model.state.places.clear(), throwsUnsupportedError);
      expect(
        () => model.state.pendingFavorites.add('x'),
        throwsUnsupportedError,
      );
    },
  );
  testWidgets(
    'search debounce trims input, cancels old work and refresh retains search/category',
    (tester) async {
      final repo = FakeMarketplaceRepository(populated: true),
          model = MarketplaceViewModel(repository: FakeMarketplaceRepository());
      model.dispose();
      final vm = MarketplaceViewModel(repository: repo);
      await vm.initialize();
      vm.setSearch('  Coffee ');
      await tester.pump(const Duration(milliseconds: 349));
      expect(repo.placeCalls, 1);
      vm.setSearch(' Coffee House ');
      await tester.pump(const Duration(milliseconds: 350));
      expect(repo.placeQueries.last.search, 'Coffee House');
      await vm.selectCategory('fictional-coffee');
      expect(repo.placeQueries.last.category, 'fictional-coffee');
      expect(repo.placeQueries.last.page, 1);
      await vm.refresh();
      expect(repo.placeQueries.last.search, 'Coffee House');
      expect(repo.placeQueries.last.category, 'fictional-coffee');
      vm.dispose();
    },
  );
  testWidgets(
    'older search and load-more responses cannot replace a newer filter',
    (tester) async {
      final repo = FakeMarketplaceRepository(populated: true);
      final vm = MarketplaceViewModel(repository: repo);
      await vm.initialize();
      final stale = Completer<MarketplacePage<MarketplacePlaceSummary>>();
      repo.onPlaces = (search, category, page, limit) => search == 'old'
          ? stale.future
          : Future.value(
              marketPage([
                MarketplacePlaceSummary.fromJson(placeJson(name: 'Newest')),
              ]),
            );
      vm.setSearch('old');
      await tester.pump(const Duration(milliseconds: 350));
      vm.setSearch('new');
      await tester.pump(const Duration(milliseconds: 350));
      expect(vm.state.places.single.name, 'Newest');
      stale.complete(
        marketPage([
          MarketplacePlaceSummary.fromJson(placeJson(name: 'Obsolete')),
        ]),
      );
      await tester.pump();
      expect(vm.state.places.single.name, 'Newest');
      vm.dispose();
    },
  );
  test('pagination appends without duplicate IDs and prevents duplicate load commands', () async {
    final repo = FakeMarketplaceRepository(populated: true);
    final a = repo.items[0], b = repo.items[1];
    final gate = Completer<MarketplacePage<MarketplacePlaceSummary>>();
    repo.onPlaces = (s, c, p, l) async =>
        p == 1 ? marketPage([a], limit: 1, total: 2) : gate.future;
    final vm = MarketplaceViewModel(repository: repo);
    addTearDown(vm.dispose);
    await vm.initialize();
    final pending = vm.loadMorePlaces();
    await vm.loadMorePlaces();
    expect(repo.placeCalls, 2);
    expect(vm.state.loadingMorePlaces, isTrue);
    gate.complete(marketPage([a, b], page: 2, limit: 2, total: 3));
    await pending;
    expect(vm.state.places.map((p) => p.id).toSet().length, 2);
  });
  test(
    'posts append without duplicates, retain order, and stop at the last page',
    () async {
      final repo = FakeMarketplaceRepository(withPosts: true);
      final one = repo.postsData.first, two = repo.postsData.last;
      repo.onPosts = (page) async => page == 1
          ? marketPage([one], limit: 1, total: 2)
          : marketPage([one, two], page: 2, limit: 2, total: 3);
      final vm = MarketplaceViewModel(repository: repo);
      addTearDown(vm.dispose);
      await vm.initialize();
      await vm.loadMorePosts();
      await vm.loadMorePosts();
      expect(vm.state.posts.map((p) => p.id).toList(), [one.id, two.id]);
      expect(repo.postCalls, 2);
    },
  );
  test('refresh failure retains successful data and retry recovers', () async {
    final repo = FakeMarketplaceRepository(populated: true);
    final vm = MarketplaceViewModel(repository: repo);
    addTearDown(vm.dispose);
    await vm.initialize();
    repo.readFailure = const MarketplaceFailure(
      'NETWORK_ERROR',
      'Safe offline message.',
    );
    await vm.refresh();
    expect(vm.state.places.length, 2);
    expect(vm.state.error, 'Safe offline message.');
    repo.readFailure = null;
    await vm.refresh();
    expect(vm.state.error, isNull);
  });
  test('favorite commands wait for confirmation, prevent duplicates, refresh ordering and recover from failure', () async {
    final repo = FakeMarketplaceRepository(populated: true);
    final vm = MarketplaceViewModel(repository: repo);
    addTearDown(vm.dispose);
    await vm.initialize();
    final place = vm.state.places.last;
    repo.mutationGate = Completer();
    final pending = vm.toggleFavorite(place);
    await vm.toggleFavorite(place);
    expect(repo.favoriteCalls, 1);
    expect(vm.state.places.last.isFavorite, isFalse);
    expect(vm.state.pendingFavorites, contains(place.id));
    repo.mutationGate!.complete();
    await pending;
    expect(vm.state.places.first.id, place.id);
    expect(vm.state.places.first.isFavorite, isTrue);
    expect(repo.postCalls, 2);
    expect(vm.state.pendingFavorites, isEmpty);
    repo.mutationFailure = const MarketplaceFailure(
      'RATE_LIMITED',
      'Please wait.',
    );
    await vm.toggleFavorite(vm.state.places.first);
    expect(vm.state.places.first.isFavorite, isTrue);
    expect(vm.state.error, 'Please wait.');
  });
  testWidgets(
    'disposal cancels debounce and ignores pending results and notifications',
    (tester) async {
      final repo = FakeMarketplaceRepository();
      final gate = Completer<MarketplacePage<MarketplacePlaceSummary>>();
      repo.onPlaces = (s, c, p, l) => gate.future;
      final vm = MarketplaceViewModel(repository: repo);
      var notices = 0;
      vm.addListener(() => notices++);
      final pending = vm.initialize();
      vm.setSearch('coffee');
      vm.dispose();
      final count = notices;
      gate.complete(marketPage([]));
      await pending;
      await tester.pump(const Duration(seconds: 1));
      expect(notices, count);
      expect(repo.placeCalls, 1);
    },
  );
  test('authentication failure is presented safely while repository owns invalidation', () async {
    final repo = FakeMarketplaceRepository()
      ..readFailure = const AuthFailure('UNAUTHENTICATED', 'untrusted');
    final vm = MarketplaceViewModel(repository: repo);
    addTearDown(vm.dispose);
    await vm.initialize();
    expect(vm.state.loading, isFalse);
    expect(vm.state.error, 'Your session changed. Please log in again.');
  });
}
