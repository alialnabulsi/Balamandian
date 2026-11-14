import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/marketplace_repository.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';
import '../view_models/marketplace_view_model.dart';
import 'marketplace_category_selector.dart';
import 'marketplace_filter_sheet.dart';
import 'marketplace_search_field.dart';
import 'marketplace_place_card.dart';
import 'marketplace_post_card.dart';
import 'marketplace_loading_state.dart';
import 'marketplace_empty_state.dart';
import 'marketplace_error_state.dart';
import 'marketplace_feedback.dart';
import 'marketplace_load_more.dart';
import 'marketplace_tokens.dart';
import 'marketplace_heading.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key, required this.repository});
  final MarketplaceRepository repository;
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  late final MarketplaceViewModel _model = MarketplaceViewModel(
    repository: widget.repository,
  );
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    unawaited(_model.initialize());
  }

  @override
  void dispose() {
    _search.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _open(String id) async {
    await context.push<void>('/market/$id');
    if (mounted) await _model.refresh();
  }

  void _filter() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (_) => MarketplaceFilterSheet(
      categories: _model.state.categories,
      selected: _model.state.category,
      onSelected: (slug) => unawaited(_model.selectCategory(slug)),
    ),
  );
  @override
  Widget build(BuildContext context) => AppBrandedBackground(
    child: ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final state = _model.state, theme = Theme.of(context);
        return RefreshIndicator(
          onRefresh: _model.refresh,
          child: ListView(
            key: const PageStorageKey('marketplace-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: MarketplaceTokens.maxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MarketplaceHeading(),
                      const SizedBox(height: 20),
                      MarketplaceSearchField(
                        controller: _search,
                        onChanged: _model.setSearch,
                        onFilter: _filter,
                      ),
                      const SizedBox(height: 8),
                      MarketplaceCategorySelector(
                        categories: state.categories,
                        selected: state.category,
                        onSelected: (slug) =>
                            unawaited(_model.selectCategory(slug)),
                      ),
                      if (state.refreshing)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Refreshing marketplace',
                        ),
                      if (state.error != null)
                        MarketplaceErrorState(
                          message: state.error!,
                          onRetry: () => unawaited(_model.refresh()),
                        ),
                      if (state.feedback != null)
                        MarketplaceFeedback(message: state.feedback!),
                      if (state.loading)
                        const MarketplaceLoadingState()
                      else ...[
                        if (state.posts.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'News & offers',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (final post in state.posts)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: SizedBox(
                                            width: constraints.maxWidth
                                                .clamp(0, 340)
                                                .toDouble(),
                                            child: MarketplacePostCard(
                                              post: post,
                                              onOpen: () => unawaited(
                                                _open(post.place.id),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                          ),
                          MarketplaceLoadMore(
                            hasNext: state.postPagination?.hasNextPage ?? false,
                            pending: state.loadingMorePosts,
                            onPressed: () => unawaited(_model.loadMorePosts()),
                            label: 'Load more posts',
                            endLabel: 'All posts loaded',
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Places',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Discover local places and services.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (state.loadingPlaces && state.places.isEmpty)
                          const MarketplaceLoadingState()
                        else if (state.places.isEmpty && state.error == null)
                          MarketplaceEmptyState(
                            search: state.search,
                            filtered: state.category != null,
                          )
                        else ...[
                          for (final place in state.places)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: MarketplacePlaceCard(
                                place: place,
                                favoritePending: state.pendingFavorites
                                    .contains(place.id),
                                onFavorite: () =>
                                    unawaited(_model.toggleFavorite(place)),
                                onOpen: () => unawaited(_open(place.id)),
                              ),
                            ),
                          if (state.places.isNotEmpty)
                            MarketplaceLoadMore(
                              hasNext:
                                  state.placePagination?.hasNextPage ?? false,
                              pending: state.loadingMorePlaces,
                              onPressed: () =>
                                  unawaited(_model.loadMorePlaces()),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
