import '../../domain/models/marketplace_models.dart';

abstract class MarketplaceRepository {
  Future<List<MarketplaceCategory>> categories();
  Future<MarketplacePage<MarketplacePlaceSummary>> places({
    String? search,
    String? category,
    int page = 1,
    int limit = 20,
  });
  Future<MarketplacePlaceDetail> place(String id);
  Future<MarketplacePage<MarketplacePost>> posts({
    String? type,
    String? placeId,
    int page = 1,
    int limit = 20,
  });
  Future<MarketplaceFavoriteResult> favorite(String id, bool value);
  Future<MarketplaceRatingResult> rating(String id, int? value);
}
