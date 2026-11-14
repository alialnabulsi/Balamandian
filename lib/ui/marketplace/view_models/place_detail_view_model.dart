import 'package:flutter/foundation.dart';

import '../../../data/repositories/marketplace_repository.dart';
import '../../../data/services/external_url_service.dart';
import '../../../domain/models/marketplace_models.dart';
import 'marketplace_feedback.dart';

class PlaceDetailState {
  PlaceDetailState({
    this.detail,
    List<MarketplacePost> posts = const [],
    this.pagination,
    this.loading = true,
    this.loadingPosts = false,
    this.loadingMore = false,
    this.favoritePending = false,
    this.ratingPending = false,
    this.launchPending = false,
    this.error,
    this.feedback,
  }) : posts = List.unmodifiable(posts);
  final MarketplacePlaceDetail? detail;
  final List<MarketplacePost> posts;
  final MarketplacePagination? pagination;
  final bool loading,
      loadingPosts,
      loadingMore,
      favoritePending,
      ratingPending,
      launchPending;
  final String? error, feedback;
  PlaceDetailState copyWith({
    MarketplacePlaceDetail? detail,
    List<MarketplacePost>? posts,
    MarketplacePagination? pagination,
    bool? loading,
    bool? loadingPosts,
    bool? loadingMore,
    bool? favoritePending,
    bool? ratingPending,
    bool? launchPending,
    String? error,
    String? feedback,
    bool clearMessages = false,
  }) => PlaceDetailState(
    detail: detail ?? this.detail,
    posts: posts ?? this.posts,
    pagination: pagination ?? this.pagination,
    loading: loading ?? this.loading,
    loadingPosts: loadingPosts ?? this.loadingPosts,
    loadingMore: loadingMore ?? this.loadingMore,
    favoritePending: favoritePending ?? this.favoritePending,
    ratingPending: ratingPending ?? this.ratingPending,
    launchPending: launchPending ?? this.launchPending,
    error: clearMessages ? null : error ?? this.error,
    feedback: clearMessages ? null : feedback ?? this.feedback,
  );
}

class PlaceDetailViewModel extends ChangeNotifier {
  PlaceDetailViewModel({
    required this.placeId,
    required this._repository,
    required ExternalUrlService externalUrls,
  }) : _external = externalUrls;
  final String placeId;
  final MarketplaceRepository _repository;
  final ExternalUrlService _external;
  PlaceDetailState _state = PlaceDetailState();
  PlaceDetailState get state => _state;
  bool _disposed = false, _initialized = false;
  int _generation = 0;
  void _publish(PlaceDetailState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_disposed || _initialized) return;
    _initialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed || _state.favoritePending || _state.ratingPending) return;
    final generation = ++_generation;
    _publish(
      _state.copyWith(loading: _state.detail == null, clearMessages: true),
    );
    try {
      final detail = await _repository.place(placeId);
      if (_disposed || generation != _generation) return;
      _publish(_state.copyWith(detail: detail, loading: false));
      await _posts(generation);
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _publish(_state.copyWith(error: marketplaceMessage(e), loading: false));
      }
    }
  }

  Future<void> _posts(int generation) async {
    _publish(_state.copyWith(loadingPosts: true));
    try {
      final page = await _repository.posts(placeId: placeId);
      if (!_disposed && generation == _generation) {
        _publish(
          _state.copyWith(
            posts: page.items,
            pagination: page.pagination,
            loadingPosts: false,
          ),
        );
      }
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _publish(
          _state.copyWith(error: marketplaceMessage(e), loadingPosts: false),
        );
      }
    }
  }

  Future<void> loadMorePosts() async {
    final page = _state.pagination, generation = _generation;
    if (_disposed ||
        _state.loadingPosts ||
        _state.loadingMore ||
        page == null ||
        !page.hasNextPage) {
      return;
    }
    _publish(_state.copyWith(loadingMore: true, clearMessages: true));
    try {
      final result = await _repository.posts(
        placeId: placeId,
        page: page.page + 1,
        limit: page.limit,
      );
      if (!_disposed && generation == _generation) {
        _publish(
          _state.copyWith(
            posts: {
              for (final p in _state.posts) p.id: p,
              for (final p in result.items) p.id: p,
            }.values.toList(),
            pagination: result.pagination,
            loadingMore: false,
          ),
        );
      }
    } catch (e) {
      if (!_disposed && generation == _generation) {
        _publish(
          _state.copyWith(error: marketplaceMessage(e), loadingMore: false),
        );
      }
    }
  }

  Future<void> toggleFavorite() async {
    final detail = _state.detail;
    if (_disposed || detail == null || _state.favoritePending) return;
    _generation++;
    _publish(
      _state.copyWith(
        favoritePending: true,
        loadingPosts: false,
        loadingMore: false,
        clearMessages: true,
      ),
    );
    try {
      final result = await _repository.favorite(
        placeId,
        !detail.place.isFavorite,
      );
      if (!_disposed) {
        _publish(
          _state.copyWith(
            detail: _state.detail!.copyWith(isFavorite: result.isFavorite),
            feedback: result.isFavorite
                ? 'Saved to favorites.'
                : 'Removed from favorites.',
          ),
        );
        await _posts(_generation);
      }
    } catch (e) {
      if (!_disposed) _publish(_state.copyWith(error: marketplaceMessage(e)));
    } finally {
      if (!_disposed) _publish(_state.copyWith(favoritePending: false));
    }
  }

  Future<void> rate(int? value) async {
    if (_disposed || _state.detail == null || _state.ratingPending) return;
    if (value != null && (value < 1 || value > 5)) return;
    _generation++;
    _publish(
      _state.copyWith(
        ratingPending: true,
        loadingPosts: false,
        loadingMore: false,
        clearMessages: true,
      ),
    );
    try {
      final result = await _repository.rating(placeId, value);
      if (!_disposed) {
        _publish(
          _state.copyWith(
            detail: _state.detail!.copyWith(rating: result),
            feedback: value == null
                ? 'Your rating was removed.'
                : 'Your rating was saved.',
          ),
        );
      }
    } catch (e) {
      if (!_disposed) _publish(_state.copyWith(error: marketplaceMessage(e)));
    } finally {
      if (!_disposed) _publish(_state.copyWith(ratingPending: false));
    }
  }

  Uri? get location {
    final d = _state.detail;
    if (d == null) return null;
    if (d.googleMapsUrl != null) return Uri.parse(d.googleMapsUrl!);
    if (d.latitude != null && d.longitude != null) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${d.latitude},${d.longitude}',
      });
    }
    return null;
  }

  Future<void> openLocation() => openUrl(location);
  Future<void> openUrl(Uri? uri) async {
    if (_disposed || uri == null || _state.launchPending) return;
    _publish(_state.copyWith(launchPending: true, clearMessages: true));
    try {
      if (!await _external.launch(uri) && !_disposed) {
        _publish(
          _state.copyWith(
            error: 'This link could not be opened. Please try again.',
          ),
        );
      }
    } catch (_) {
      if (!_disposed) {
        _publish(
          _state.copyWith(
            error: 'This link could not be opened. Please try again.',
          ),
        );
      }
    } finally {
      if (!_disposed) _publish(_state.copyWith(launchPending: false));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
