import 'dart:async';

import 'package:balamandian/domain/models/marketplace_models.dart';
import 'package:balamandian/ui/marketplace/view_models/place_detail_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../marketplace_test_support.dart';

void main() {
  test('detail loads once and rating create/replace/remove uses returned aggregates', () async {
    final repo = FakeMarketplaceRepository();
    final vm = PlaceDetailViewModel(
      placeId: marketPlaceId,
      repository: repo,
      externalUrls: FakeExternalUrlService(),
    );
    addTearDown(vm.dispose);
    await vm.initialize();
    await vm.initialize();
    expect(repo.detailCalls, 1);
    for (final value in [1, 5, null]) {
      await vm.rate(value);
      expect(vm.state.detail!.place.myRating, value);
      expect(vm.state.detail!.place.averageRating, value?.toDouble() ?? 0);
      expect(vm.state.detail!.place.ratingCount, value == null ? 0 : 1);
    }
    expect(repo.ratingCalls, 3);
    expect(vm.state.feedback, 'Your rating was removed.');
  });
  test(
    'mutations disable duplicate commands and failures retain confirmed values',
    () async {
      final repo = FakeMarketplaceRepository();
      final vm = PlaceDetailViewModel(
        placeId: marketPlaceId,
        repository: repo,
        externalUrls: FakeExternalUrlService(),
      );
      addTearDown(vm.dispose);
      await vm.initialize();
      repo.mutationGate = Completer();
      final rating = vm.rate(4);
      await vm.rate(5);
      expect(repo.ratingCalls, 1);
      expect(vm.state.ratingPending, isTrue);
      expect(vm.state.detail!.place.myRating, isNull);
      repo.mutationGate!.complete();
      await rating;
      repo.mutationFailure = const MarketplaceFailure(
        'RATE_LIMITED',
        'Safe wait.',
      );
      await vm.rate(5);
      expect(vm.state.detail!.place.myRating, 4);
      expect(vm.state.error, 'Safe wait.');
      await vm.toggleFavorite();
      expect(vm.state.detail!.place.isFavorite, isFalse);
      repo.mutationFailure = null;
      await vm.toggleFavorite();
      expect(vm.state.detail!.place.isFavorite, isTrue);
    },
  );
  test('stale detail refresh cannot overwrite a confirmed mutation', () async {
    final repo = FakeMarketplaceRepository();
    final vm = PlaceDetailViewModel(
      placeId: marketPlaceId,
      repository: repo,
      externalUrls: FakeExternalUrlService(),
    );
    addTearDown(vm.dispose);
    await vm.initialize();
    final old = vm.state.detail!;
    final gate = Completer<MarketplacePlaceDetail>();
    repo.onDetail = () => gate.future;
    final refreshing = vm.refresh();
    await vm.rate(5);
    gate.complete(old);
    await refreshing;
    expect(vm.state.detail!.place.myRating, 5);
  });
  test('location prefers explicit URL, falls back to coordinates, and safely reports launch failure', () async {
    final repo = FakeMarketplaceRepository();
    final external = FakeExternalUrlService();
    final vm = PlaceDetailViewModel(
      placeId: marketPlaceId,
      repository: repo,
      externalUrls: external,
    );
    addTearDown(vm.dispose);
    await vm.initialize();
    expect(vm.location!.queryParameters['query'], '34.1,35.2');
    await vm.openLocation();
    expect(external.launched.single.scheme, 'https');
    repo.detail = MarketplacePlaceDetail.fromJson({
      ...detailJson(),
      'googleMapsUrl': 'https://example.invalid/maps',
    });
    await vm.refresh();
    expect(vm.location.toString(), 'https://example.invalid/maps');
    external.result = false;
    await vm.openLocation();
    expect(vm.state.error, contains('could not be opened'));
    repo.detail = MarketplacePlaceDetail.fromJson({
      ...detailJson(),
      'latitude': null,
      'longitude': null,
    });
    await vm.refresh();
    expect(vm.location, isNull);
    await vm.openLocation();
    expect(external.launched.length, 2);
  });
  test(
    'failed first load, refresh retry, posts pagination and disposal are safe',
    () async {
      final repo = FakeMarketplaceRepository(withPosts: true)
        ..readFailure = const MarketplaceFailure('NETWORK_ERROR', 'Try again.');
      final vm = PlaceDetailViewModel(
        placeId: marketPlaceId,
        repository: repo,
        externalUrls: FakeExternalUrlService(),
      );
      await vm.initialize();
      expect(vm.state.detail, isNull);
      expect(vm.state.error, 'Try again.');
      repo.readFailure = null;
      await vm.refresh();
      final detail = vm.state.detail;
      repo.readFailure = StateError('private');
      await vm.refresh();
      expect(vm.state.detail, same(detail));
      expect(vm.state.error, isNot(contains('private')));
      repo.readFailure = null;
      final gate = Completer<MarketplacePlaceDetail>();
      repo.onDetail = () => gate.future;
      final pending = vm.refresh();
      vm.dispose();
      gate.complete(repo.detail);
      await pending;
    },
  );
}
