import 'marketplace_json.dart';

class MarketplaceFavoriteResult {
  const MarketplaceFavoriteResult({
    required this.placeId,
    required this.isFavorite,
  });
  final String placeId;
  final bool isFavorite;
  factory MarketplaceFavoriteResult.fromJson(Object? value) {
    final j = MarketplaceJson.object(value);
    return MarketplaceFavoriteResult(
      placeId: MarketplaceJson.id(j, 'placeId'),
      isFavorite: MarketplaceJson.boolean(j, 'isFavorite'),
    );
  }
}
