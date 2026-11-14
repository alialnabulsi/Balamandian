import '../../domain/models/auth_failure.dart';
import '../../domain/models/marketplace_models.dart';
import '../services/marketplace_api_service.dart';
import 'marketplace_repository.dart';

typedef AuthenticatedMarketplaceRequest = Future<T> Function<T>(
  Future<T> Function(String token) request,
);

class ApiMarketplaceRepository implements MarketplaceRepository {
  ApiMarketplaceRepository({required this._api, required this._withSession});
  final MarketplaceApiService _api;
  final AuthenticatedMarketplaceRequest _withSession;
  Future<T> _run<T>(Future<T> Function(String) operation) async {
    try {
      return await _withSession(operation);
    } on AuthFailure {
      rethrow;
    } on MarketplaceFailure {
      rethrow;
    } catch (_) {
      throw const MarketplaceFailure(
        'SERVICE_ERROR',
        'Marketplace is unavailable. Please try again later.',
      );
    }
  }

  @override
  Future<List<MarketplaceCategory>> categories() => _run(_api.categories);
  @override
  Future<MarketplacePage<MarketplacePlaceSummary>> places({
    String? search,
    String? category,
    int page = 1,
    int limit = 20,
  }) => _run(
    (token) => _api.places(
      token,
      search: search,
      category: category,
      page: page,
      limit: limit,
    ),
  );
  @override
  Future<MarketplacePlaceDetail> place(String id) =>
      _run((token) => _api.place(token, id));
  @override
  Future<MarketplacePage<MarketplacePost>> posts({
    String? type,
    String? placeId,
    int page = 1,
    int limit = 20,
  }) => _run(
    (token) => _api.posts(
      token,
      type: type,
      placeId: placeId,
      page: page,
      limit: limit,
    ),
  );
  @override
  Future<MarketplaceFavoriteResult> favorite(String id, bool value) =>
      _run((token) => _api.favorite(token, id, value));
  @override
  Future<MarketplaceRatingResult> rating(String id, int? value) =>
      _run((token) => _api.rating(token, id, value));
}
