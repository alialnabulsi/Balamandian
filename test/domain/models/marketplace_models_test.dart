import 'package:balamandian/domain/models/marketplace_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../marketplace_test_support.dart';

void main() {
  test('all marketplace contracts parse with deliberate numeric, nullable and UTC types', () {
    final category = MarketplaceCategory.fromJson(categoryJson());
    expect(category.sortOrder, 10);
    final place = MarketplacePlaceSummary.fromJson(placeJson());
    expect(place.averageRating, isA<double>());
    expect(place.myRating, isNull);
    expect(place.coverImageUrl, isNull);
    final detail = MarketplacePlaceDetail.fromJson(detailJson());
    expect(detail.latitude, 34.1);
    expect(detail.longitude, 35.2);
    expect(detail.images.single.alternativeText, 'Fictional storefront');
    expect(detail.openingHours.last.crossesMidnight, isTrue);
    final post = MarketplacePost.fromJson(postJson());
    expect(post.startsAt.isUtc, isTrue);
    expect(post.startsAt.toIso8601String(), '2026-01-01T00:00:00.000Z');
    expect(post.endsAt, isNull);
    expect(
      MarketplacePost.fromJson({
        ...postJson(),
        'endsAt': '2027-01-01T00:00:00Z',
      }).endsAt!.isUtc,
      isTrue,
    );
    final page = MarketplacePage.fromJson({
      'items': [placeJson()],
      'pagination': paginationJson(),
    }, MarketplacePlaceSummary.fromJson);
    expect(page.items.length, 1);
    expect(() => page.items.clear(), throwsUnsupportedError);
    final favorite = MarketplaceFavoriteResult.fromJson({
      'placeId': marketPlaceId,
      'isFavorite': true,
    });
    expect(favorite.isFavorite, isTrue);
    final rating = MarketplaceRatingResult.fromJson({
      'placeId': marketPlaceId,
      'myRating': 4,
      'averageRating': 4,
      'ratingCount': 1,
    });
    expect(rating.averageRating, 4.0);
    expect(place.copyWith(rating: rating, isFavorite: true).myRating, 4);
    final removed = MarketplaceRatingResult(
      placeId: marketPlaceId,
      myRating: null,
      averageRating: 0,
      ratingCount: 0,
    );
    expect(
      detail.copyWith(rating: rating).copyWith(rating: removed).place.myRating,
      isNull,
    );
  });
  test(
    'detail preserves null coordinates, links and gallery alternative text',
    () {
      final detail = MarketplacePlaceDetail.fromJson({
        ...detailJson(),
        'latitude': null,
        'longitude': null,
        'phoneNumber': null,
        'websiteUrl': null,
        'socialUrl': null,
        'images': [
          {
            ...Map<String, dynamic>.from(
              (detailJson()['images'] as List).single as Map,
            ),
            'alternativeText': null,
          },
        ],
      });
      expect(detail.latitude, isNull);
      expect(detail.images.single.alternativeText, isNull);
      expect(() => detail.images.clear(), throwsUnsupportedError);
    },
  );
  for (final bad in [null, [], {}, 'text']) {
    test('malformed root object $bad is rejected', () {
      expect(
        () => MarketplacePlaceSummary.fromJson(bad),
        throwsFormatException,
      );
    });
  }
  test('required summary field types and values are strictly checked', () {
    for (final key in placeJson().keys) {
      final json = placeJson()..remove(key);
      expect(
        () => MarketplacePlaceSummary.fromJson(json),
        throwsFormatException,
        reason: key,
      );
    }
    for (final entry in {
      'id': 'bad',
      'name': ' ',
      'coverImageUrl': 'http://insecure.invalid',
      'averageRating': '4',
      'ratingCount': 1.0,
      'myRating': 6,
      'isFavorite': 1,
      'category': [],
    }.entries) {
      expect(
        () => MarketplacePlaceSummary.fromJson({
          ...placeJson(),
          entry.key: entry.value,
        }),
        throwsFormatException,
      );
    }
  });
  test('all detail fields are required even when nullable', () {
    for (final key in detailJson().keys) {
      final json = detailJson()..remove(key);
      expect(
        () => MarketplacePlaceDetail.fromJson(json),
        throwsFormatException,
        reason: key,
      );
    }
  });
  test('invalid coordinates, hours, dates, post types, pages and mutation shapes fail safely', () {
    expect(
      () =>
          MarketplacePlaceDetail.fromJson({...detailJson(), 'longitude': null}),
      throwsFormatException,
    );
    expect(
      () =>
          MarketplacePlaceDetail.fromJson({...detailJson(), 'latitude': '34'}),
      throwsFormatException,
    );
    expect(
      () => MarketplaceOpeningHour.fromJson({
        'dayOfWeek': 8,
        'opensAt': '07:30',
        'closesAt': '20:00',
      }),
      throwsFormatException,
    );
    expect(
      () => MarketplaceOpeningHour.fromJson({
        'dayOfWeek': 1,
        'opensAt': '25:00',
        'closesAt': '20:00',
      }),
      throwsFormatException,
    );
    for (final j in [
      {...postJson(), 'type': 'review'},
      {...postJson(), 'startsAt': 'yesterday'},
      {...postJson(), 'startsAt': '2026-01-01T00:00:00'},
      {...postJson(), 'endsAt': '2025-01-01T00:00:00Z'},
    ]) {
      expect(() => MarketplacePost.fromJson(j), throwsFormatException);
    }
    expect(
      () => MarketplacePagination.fromJson({
        ...paginationJson(),
        'hasNextPage': true,
      }),
      throwsFormatException,
    );
    expect(
      () => MarketplacePage.fromJson({
        'items': null,
        'pagination': paginationJson(),
      }, MarketplacePlaceSummary.fromJson),
      throwsFormatException,
    );
    expect(
      () => MarketplaceFavoriteResult.fromJson({
        'placeId': marketPlaceId,
        'isFavorite': 'yes',
      }),
      throwsFormatException,
    );
    expect(
      () => MarketplaceRatingResult.fromJson({
        'placeId': marketPlaceId,
        'myRating': 0,
        'averageRating': 6,
        'ratingCount': -1,
      }),
      throwsFormatException,
    );
  });
}
