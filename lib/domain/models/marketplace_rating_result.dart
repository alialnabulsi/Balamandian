import 'marketplace_json.dart';

class MarketplaceRatingResult {
  const MarketplaceRatingResult({
    required this.placeId,
    required this.myRating,
    required this.averageRating,
    required this.ratingCount,
  });
  final String placeId;
  final int? myRating;
  final double averageRating;
  final int ratingCount;
  factory MarketplaceRatingResult.fromJson(Object? value) {
    final j = MarketplaceJson.object(value);
    return MarketplaceRatingResult(
      placeId: MarketplaceJson.id(j, 'placeId'),
      myRating: MarketplaceJson.rating(j, 'myRating'),
      averageRating: MarketplaceJson.number(j, 'averageRating'),
      ratingCount: MarketplaceJson.integer(j, 'ratingCount'),
    );
  }
}
