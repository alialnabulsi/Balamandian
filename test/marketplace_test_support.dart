import 'dart:async';

import 'package:balamandian/data/repositories/marketplace_repository.dart';
import 'package:balamandian/data/services/external_url_service.dart';
import 'package:balamandian/domain/models/marketplace_models.dart';

const marketPlaceId = '22222222-2222-4222-8222-222222222222';
const marketOtherId = '22222222-2222-4222-8222-333333333333';
const marketCategoryId = '11111111-1111-4111-8111-111111111111';
Map<String, dynamic> categoryJson() => {
  'id': marketCategoryId,
  'name': 'Coffee & bites',
  'slug': 'fictional-coffee',
  'iconKey': 'coffee',
  'sortOrder': 10,
};
Map<String, dynamic> placeJson({
  String id = marketPlaceId,
  String name = 'Fictional Coffee House',
  String slug = 'the-olive-coffee-house',
}) => {
  'id': id,
  'name': name,
  'slug': slug,
  'description': 'A quiet coffee break, a table with friends, and something freshly baked. A fictional test listing.',
  'coverImageUrl': null,
  'address': '42 Fictional Lane',
  'category': {...categoryJson()}..remove('sortOrder'),
  'averageRating': 0,
  'ratingCount': 0,
  'myRating': null,
  'isFavorite': false,
};
Map<String, dynamic> detailJson() => {
  ...placeJson(),
  'latitude': 34.1,
  'longitude': 35.2,
  'googleMapsUrl': null,
  'phoneNumber': '+961 00 000 000',
  'websiteUrl': 'https://example.invalid',
  'socialUrl': 'https://example.invalid/social',
  'timezone': 'Asia/Beirut',
  'images': [
    {
      'id': '33333333-3333-4333-8333-333333333333',
      'imageUrl': 'https://example.invalid/gallery.jpg',
      'alternativeText': 'Fictional storefront',
      'sortOrder': 0,
    },
  ],
  'openingHours': [
    {'dayOfWeek': 1, 'opensAt': '07:30', 'closesAt': '12:00'},
    {'dayOfWeek': 1, 'opensAt': '13:00', 'closesAt': '20:00'},
    {'dayOfWeek': 6, 'opensAt': '21:00', 'closesAt': '02:00'},
  ],
};
Map<String, dynamic> postJson({String type = 'news'}) => {
  'id': '44444444-4444-4444-8444-444444444444',
  'type': type,
  'title': 'A new seasonal selection',
  'body': 'Discover the latest fictional selection at this place.',
  'imageUrl': null,
  'startsAt': '2026-01-01T02:00:00+02:00',
  'endsAt': null,
  'isFavoritePlace': false,
  'place': {
    'id': marketPlaceId,
    'name': 'Fictional Coffee House',
    'slug': 'the-olive-coffee-house',
    'coverImageUrl': null,
  },
};
Map<String, dynamic> paginationJson({
  int page = 1,
  int limit = 20,
  int total = 1,
}) => {
  'page': page,
  'limit': limit,
  'totalItems': total,
  'totalPages': (total / limit).ceil(),
  'hasNextPage': page < (total / limit).ceil(),
  'hasPreviousPage': page > 1,
};
MarketplacePage<T> marketPage<T>(
  List<T> items, {
  int page = 1,
  int limit = 20,
  int? total,
}) => MarketplacePage(
  items: items,
  pagination: MarketplacePagination.fromJson(
    paginationJson(page: page, limit: limit, total: total ?? items.length),
  ),
);

class FakeMarketplaceRepository implements MarketplaceRepository {
  FakeMarketplaceRepository({bool populated = false, bool withPosts = false}) {
    if (populated) {
      items = [
        MarketplacePlaceSummary.fromJson(placeJson()),
        MarketplacePlaceSummary.fromJson(
          placeJson(
            id: marketOtherId,
            name: 'Fictional Garden Table',
            slug: 'the-garden-table',
          ),
        ),
      ];
      categoriesData = [
        MarketplaceCategory.fromJson(categoryJson()),
        const MarketplaceCategory(
          id: '11111111-1111-4111-8111-222222222222',
          name: 'Food & dining',
          slug: 'fictional-food',
          iconKey: 'restaurant',
        ),
        const MarketplaceCategory(
          id: '11111111-1111-4111-8111-333333333333',
          name: 'Books & printing',
          slug: 'fictional-books',
          iconKey: 'books',
        ),
      ];
    }
    if (withPosts) {
      postsData = [
        MarketplacePost.fromJson(postJson()),
        MarketplacePost.fromJson({
          ...postJson(type: 'advertisement'),
          'id': '44444444-4444-4444-8444-555555555555',
        }),
      ];
    }
  }
  List<MarketplacePlaceSummary> items = [];
  List<MarketplaceCategory> categoriesData = [];
  List<MarketplacePost> postsData = [];
  MarketplacePlaceDetail detail = MarketplacePlaceDetail.fromJson({
    ...detailJson(),
    'images': [],
  });
  Object? readFailure, mutationFailure;
  Completer<void>? mutationGate;
  int categoryCalls = 0,
      placeCalls = 0,
      detailCalls = 0,
      postCalls = 0,
      favoriteCalls = 0,
      ratingCalls = 0;
  final placeQueries = <({String? search, String? category, int page})>[];
  Future<MarketplacePage<MarketplacePlaceSummary>> Function(
    String? search,
    String? category,
    int page,
    int limit,
  )?
  onPlaces;
  Future<MarketplacePlaceDetail> Function()? onDetail;
  Future<MarketplacePage<MarketplacePost>> Function(int page)? onPosts;
  void _read() {
    if (readFailure != null) throw readFailure!;
  }

  @override
  Future<List<MarketplaceCategory>> categories() async {
    categoryCalls++;
    _read();
    return List.unmodifiable(categoriesData);
  }

  @override
  Future<MarketplacePage<MarketplacePlaceSummary>> places({
    String? search,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    placeCalls++;
    placeQueries.add((search: search, category: category, page: page));
    _read();
    if (onPlaces != null) return onPlaces!(search, category, page, limit);
    final data =
        items
            .where(
              (p) =>
                  (search == null ||
                      p.name.toLowerCase().contains(search.toLowerCase())) &&
                  (category == null || p.category.slug == category),
            )
            .toList()
          ..sort((a, b) {
            if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
            final rating = b.averageRating.compareTo(a.averageRating);
            return rating != 0 ? rating : a.name.compareTo(b.name);
          });
    return marketPage(
      data.skip((page - 1) * limit).take(limit).toList(),
      page: page,
      limit: limit,
      total: data.length,
    );
  }

  @override
  Future<MarketplacePlaceDetail> place(String id) async {
    detailCalls++;
    _read();
    if (onDetail != null) return onDetail!();
    return detail;
  }

  @override
  Future<MarketplacePage<MarketplacePost>> posts({
    String? type,
    String? placeId,
    int page = 1,
    int limit = 20,
  }) async {
    postCalls++;
    _read();
    if (onPosts != null) return onPosts!(page);
    final data = postsData
        .where(
          (p) =>
              (type == null || p.type == type) &&
              (placeId == null || p.place.id == placeId),
        )
        .toList();
    return marketPage(
      data.skip((page - 1) * limit).take(limit).toList(),
      page: page,
      limit: limit,
      total: data.length,
    );
  }

  @override
  Future<MarketplaceFavoriteResult> favorite(String id, bool value) async {
    favoriteCalls++;
    await mutationGate?.future;
    if (mutationFailure != null) throw mutationFailure!;
    items = [
      for (final p in items) p.id == id ? p.copyWith(isFavorite: value) : p,
    ];
    detail = detail.copyWith(isFavorite: value);
    return MarketplaceFavoriteResult(placeId: id, isFavorite: value);
  }

  @override
  Future<MarketplaceRatingResult> rating(String id, int? value) async {
    ratingCalls++;
    await mutationGate?.future;
    if (mutationFailure != null) throw mutationFailure!;
    final result = MarketplaceRatingResult(
      placeId: id,
      myRating: value,
      averageRating: value?.toDouble() ?? 0,
      ratingCount: value == null ? 0 : 1,
    );
    detail = detail.copyWith(rating: result);
    items = [
      for (final p in items) p.id == id ? p.copyWith(rating: result) : p,
    ];
    return result;
  }
}

class FakeExternalUrlService implements ExternalUrlService {
  bool result = true;
  Object? failure;
  final List<Uri> launched = [];
  @override
  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    if (failure != null) throw failure!;
    return result;
  }
}
