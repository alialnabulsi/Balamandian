import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/marketplace_repository.dart';
import '../../../data/services/external_url_service.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';
import '../view_models/place_detail_view_model.dart';
import 'marketplace_cover_gallery.dart';
import 'marketplace_favorite_button.dart';
import 'marketplace_rating_summary.dart';
import 'marketplace_star_input.dart';
import 'marketplace_opening_hours.dart';
import 'marketplace_location_section.dart';
import 'marketplace_contact_actions.dart';
import 'marketplace_detail_posts.dart';
import 'marketplace_loading_state.dart';
import 'marketplace_error_state.dart';
import 'marketplace_feedback.dart';
import 'marketplace_tokens.dart';

class PlaceDetailScreen extends StatefulWidget {
  const PlaceDetailScreen({
    super.key,
    required this.placeId,
    required this.repository,
    required this.externalUrls,
  });
  final String placeId;
  final MarketplaceRepository repository;
  final ExternalUrlService externalUrls;
  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late final PlaceDetailViewModel _model = PlaceDetailViewModel(
    placeId: widget.placeId,
    repository: widget.repository,
    externalUrls: widget.externalUrls,
  );
  final _top = GlobalKey();
  @override
  void initState() {
    super.initState();
    unawaited(_model.initialize());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppBrandedBackground(
    child: ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final state = _model.state,
            detail = state.detail,
            theme = Theme.of(context);
        return RefreshIndicator(
          onRefresh: _model.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: MarketplaceTokens.maxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        key: _top,
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/market');
                            }
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Marketplace'),
                        ),
                      ),
                      if (state.loading) const MarketplaceLoadingState(),
                      if (state.error != null)
                        MarketplaceErrorState(
                          message: state.error!,
                          onRetry: () => unawaited(_model.refresh()),
                        ),
                      if (state.feedback != null)
                        MarketplaceFeedback(message: state.feedback!),
                      if (detail != null) ...[
                        MarketplaceCoverGallery(detail: detail),
                        const SizedBox(height: 18),
                        Text(
                          detail.place.category.name.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                detail.place.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            MarketplaceFavoriteButton(
                              isFavorite: detail.place.isFavorite,
                              pending: state.favoritePending,
                              onPressed: () =>
                                  unawaited(_model.toggleFavorite()),
                              placeName: detail.place.name,
                            ),
                          ],
                        ),
                        MarketplaceRatingSummary(
                          average: detail.place.averageRating,
                          count: detail.place.ratingCount,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          detail.place.description,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        MarketplaceContactActions(
                          onPhone:
                              detail.phoneNumber == null || state.launchPending
                              ? null
                              : () => unawaited(
                                  _model.openUrl(
                                    Uri(
                                      scheme: 'tel',
                                      path: detail.phoneNumber,
                                    ),
                                  ),
                                ),
                          onWebsite:
                              detail.websiteUrl == null || state.launchPending
                              ? null
                              : () => unawaited(
                                  _model.openUrl(Uri.parse(detail.websiteUrl!)),
                                ),
                          onSocial:
                              detail.socialUrl == null || state.launchPending
                              ? null
                              : () => unawaited(
                                  _model.openUrl(Uri.parse(detail.socialUrl!)),
                                ),
                        ),
                        const SizedBox(height: 16),
                        MarketplaceLocationSection(
                          address: detail.place.address,
                          onDirections:
                              _model.location == null || state.launchPending
                              ? null
                              : () => unawaited(_model.openLocation()),
                        ),
                        const Divider(height: 32),
                        MarketplaceStarInput(
                          rating: detail.place.myRating,
                          pending: state.ratingPending,
                          onRate: (value) => unawaited(_model.rate(value)),
                          onRemove: () => unawaited(_model.rate(null)),
                        ),
                        const Divider(height: 32),
                        MarketplaceOpeningHours(
                          hours: detail.openingHours,
                          timezone: detail.timezone,
                        ),
                        const SizedBox(height: 16),
                        MarketplaceDetailPosts(
                          posts: state.posts,
                          loading: state.loadingPosts,
                          loadingMore: state.loadingMore,
                          hasNext: state.pagination?.hasNextPage ?? false,
                          onLoadMore: () => unawaited(_model.loadMorePosts()),
                          onOpen: (_) => Scrollable.ensureVisible(
                            _top.currentContext!,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                          ),
                        ),
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
