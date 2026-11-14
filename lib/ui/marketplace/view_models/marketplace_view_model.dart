import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/marketplace_repository.dart';
import '../../../domain/models/marketplace_models.dart';
import 'marketplace_feedback.dart';

class MarketplaceState {
  MarketplaceState({
    List<MarketplaceCategory> categories = const [],
    List<MarketplacePlaceSummary> places = const [],
    List<MarketplacePost> posts = const [],
    Set<String> pendingFavorites = const {},
    this.search = '',
    this.category,
    this.loading = true,
    this.refreshing = false,
    this.loadingPlaces = false,
    this.loadingMorePlaces = false,
    this.loadingMorePosts = false,
    this.placePagination,
    this.postPagination,
    this.error,
    this.feedback,
  }) : categories = List.unmodifiable(categories),
       places = List.unmodifiable(places),
       posts = List.unmodifiable(posts),
       pendingFavorites = Set.unmodifiable(pendingFavorites);
  final List<MarketplaceCategory> categories;
  final List<MarketplacePlaceSummary> places;
  final List<MarketplacePost> posts;
  final Set<String> pendingFavorites;
  final String search;
  final String? category, error, feedback;
  final bool loading,
      refreshing,
      loadingPlaces,
      loadingMorePlaces,
      loadingMorePosts;
  final MarketplacePagination? placePagination, postPagination;
  MarketplaceState copyWith({
    List<MarketplaceCategory>? categories,
    List<MarketplacePlaceSummary>? places,
    List<MarketplacePost>? posts,
    Set<String>? pendingFavorites,
    String? search,
    String? category,
    bool clearCategory = false,
    bool? loading,
    bool? refreshing,
    bool? loadingPlaces,
    bool? loadingMorePlaces,
    bool? loadingMorePosts,
    MarketplacePagination? placePagination,
    MarketplacePagination? postPagination,
    bool resetPlacePage = false,
    String? error,
    String? feedback,
    bool clearMessages = false,
  }) => MarketplaceState(
    categories: categories ?? this.categories,
    places: places ?? this.places,
    posts: posts ?? this.posts,
    pendingFavorites: pendingFavorites ?? this.pendingFavorites,
    search: search ?? this.search,
    category: clearCategory ? null : category ?? this.category,
    loading: loading ?? this.loading,
    refreshing: refreshing ?? this.refreshing,
    loadingPlaces: loadingPlaces ?? this.loadingPlaces,
    loadingMorePlaces: loadingMorePlaces ?? this.loadingMorePlaces,
    loadingMorePosts: loadingMorePosts ?? this.loadingMorePosts,
    placePagination: resetPlacePage
        ? null
        : placePagination ?? this.placePagination,
    postPagination: postPagination ?? this.postPagination,
    error: clearMessages ? null : error ?? this.error,
    feedback: clearMessages ? null : feedback ?? this.feedback,
  );
}

class MarketplaceViewModel extends ChangeNotifier {
  MarketplaceViewModel({required this._repository});
  final MarketplaceRepository _repository;
  MarketplaceState _state = MarketplaceState();
  MarketplaceState get state => _state;
  Timer? _debounce;
  bool _disposed = false, _initialized = false;
  int _placesGeneration = 0, _feedGeneration = 0;
  void _publish(MarketplaceState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    _debounce?.cancel();
    final feed = ++_feedGeneration;
    _publish(_state.copyWith(refreshing: !_state.loading, clearMessages: true));
    await Future.wait([_categories(feed), _posts(feed), _places()]);
    if (!_disposed && feed == _feedGeneration) {
      _publish(_state.copyWith(loading: false, refreshing: false));
    }
  }

  Future<void> _categories(int generation) async {
    try {
      final result = await _repository.categories();
      if (!_disposed && generation == _feedGeneration) {
        _publish(_state.copyWith(categories: result));
      }
    } catch (e) {
      if (!_disposed && generation == _feedGeneration) {
        _publish(_state.copyWith(error: marketplaceMessage(e)));
      }
    }
  }

  Future<void> _posts(int generation) async {
    try {
      final result = await _repository.posts();
      if (!_disposed && generation == _feedGeneration) {
        _publish(
          _state.copyWith(
            posts: result.items,
            postPagination: result.pagination,
            loadingMorePosts: false,
          ),
        );
      }
    } catch (e) {
      if (!_disposed && generation == _feedGeneration) {
        _publish(
          _state.copyWith(
            error: marketplaceMessage(e),
            loadingMorePosts: false,
          ),
        );
      }
    }
  }

  Future<void> _places() async {
    final generation = ++_placesGeneration;
    final search = _state.search, category = _state.category;
    _publish(_state.copyWith(loadingPlaces: true, loadingMorePlaces: false));
    try {
      final result = await _repository.places(
        search: search.isEmpty ? null : search,
        category: category,
      );
      if (!_disposed && generation == _placesGeneration) {
        _publish(
          _state.copyWith(
            places: result.items,
            placePagination: result.pagination,
            loadingPlaces: false,
          ),
        );
      }
    } catch (e) {
      if (!_disposed && generation == _placesGeneration) {
        _publish(
          _state.copyWith(error: marketplaceMessage(e), loadingPlaces: false),
        );
      }
    }
  }

  void setSearch(String input) {
    if (_disposed) return;
    final search = input.trim();
    if (search == _state.search) return;
    _debounce?.cancel();
    _placesGeneration++;
    _publish(
      _state.copyWith(
        search: search,
        places: [],
        resetPlacePage: true,
        loadingPlaces: true,
        loadingMorePlaces: false,
        clearMessages: true,
      ),
    );
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_places()),
    );
  }

  Future<void> selectCategory(String? slug) async {
    if (_disposed || slug == _state.category) return;
    _debounce?.cancel();
    _publish(
      _state.copyWith(
        category: slug,
        clearCategory: slug == null,
        places: [],
        resetPlacePage: true,
        clearMessages: true,
      ),
    );
    await _places();
  }

  Future<void> loadMorePlaces() async {
    final pagination = _state.placePagination;
    if (_disposed ||
        _state.loadingMorePlaces ||
        _state.loadingPlaces ||
        pagination == null ||
        !pagination.hasNextPage) {
      return;
    }
    final generation = _placesGeneration;
    _publish(_state.copyWith(loadingMorePlaces: true, clearMessages: true));
    try {
      final result = await _repository.places(
        search: _state.search.isEmpty ? null : _state.search,
        category: _state.category,
        page: pagination.page + 1,
        limit: pagination.limit,
      );
      if (!_disposed && generation == _placesGeneration) {
        _publish(
          _state.copyWith(
            places: {
              for (final p in _state.places) p.id: p,
              for (final p in result.items) p.id: p,
            }.values.toList(),
            placePagination: result.pagination,
            loadingMorePlaces: false,
          ),
        );
      }
    } catch (e) {
      if (!_disposed && generation == _placesGeneration) {
        _publish(
          _state.copyWith(
            error: marketplaceMessage(e),
            loadingMorePlaces: false,
          ),
        );
      }
    }
  }

  Future<void> loadMorePosts() async {
    final pagination = _state.postPagination;
    if (_disposed ||
        _state.refreshing ||
        _state.loadingMorePosts ||
        pagination == null ||
        !pagination.hasNextPage) {
      return;
    }
    final generation = _feedGeneration;
    _publish(_state.copyWith(loadingMorePosts: true, clearMessages: true));
    try {
      final result = await _repository.posts(
        page: pagination.page + 1,
        limit: pagination.limit,
      );
      if (!_disposed && generation == _feedGeneration) {
        _publish(
          _state.copyWith(
            posts: {
              for (final p in _state.posts) p.id: p,
              for (final p in result.items) p.id: p,
            }.values.toList(),
            postPagination: result.pagination,
            loadingMorePosts: false,
          ),
        );
      }
    } catch (e) {
      if (!_disposed && generation == _feedGeneration) {
        _publish(
          _state.copyWith(
            error: marketplaceMessage(e),
            loadingMorePosts: false,
          ),
        );
      }
    }
  }

  Future<void> toggleFavorite(MarketplacePlaceSummary place) async {
    if (_disposed || _state.pendingFavorites.contains(place.id)) return;
    _publish(
      _state.copyWith(
        pendingFavorites: {..._state.pendingFavorites, place.id},
        clearMessages: true,
      ),
    );
    try {
      final result = await _repository.favorite(place.id, !place.isFavorite);
      if (_disposed) return;
      _publish(
        _state.copyWith(
          places: [
            for (final p in _state.places)
              p.id == result.placeId
                  ? p.copyWith(isFavorite: result.isFavorite)
                  : p,
          ],
        ),
      );
      await refresh();
      if (!_disposed) {
        _publish(
          _state.copyWith(
            feedback: result.isFavorite
                ? 'Saved to favorites.'
                : 'Removed from favorites.',
          ),
        );
      }
    } catch (e) {
      if (!_disposed) _publish(_state.copyWith(error: marketplaceMessage(e)));
    } finally {
      if (!_disposed) {
        _publish(
          _state.copyWith(
            pendingFavorites: {..._state.pendingFavorites}..remove(place.id),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _placesGeneration++;
    _feedGeneration++;
    _debounce?.cancel();
    super.dispose();
  }
}
