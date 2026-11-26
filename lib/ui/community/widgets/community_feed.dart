import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';
import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/loading/skeleton.dart';
import '../../profile/view_models/current_identity_view_model.dart';
import '../view_models/community_feed_model.dart';
import 'community_actions.dart';
import 'community_comments.dart';
import 'community_media.dart';
import 'community_post_card.dart';
import 'community_stories.dart';

class CommunityFeed extends StatefulWidget {
  const CommunityFeed({
    super.key,
    required this.repository,
    required this.identity,
    this.path = 'feed',
    this.title,
  });
  final CommunityRepository repository;
  final CurrentIdentityViewModel identity;
  final String path;
  final String? title;
  @override
  State<CommunityFeed> createState() => _CommunityFeedState();
}

class _CommunityFeedState extends State<CommunityFeed> {
  late final _model = CommunityFeedModel(
    widget.repository,
    path: widget.path,
    hasStories: widget.path == 'feed',
  );
  late final Future<void> _initial;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _initial = _model.refresh();
    unawaited(_initial);
    _scroll.addListener(_nearEnd);
  }

  void _nearEnd() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 700 &&
        _model.error == null) {
      unawaited(_model.more());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppBrandedBackground(
    variant: AppBackgroundVariant.architecture,
    child: ListenableBuilder(
      listenable: Listenable.merge([_model, widget.identity]),
      builder: (context, _) {
        final main = widget.path == 'feed';
        final theme = Theme.of(context);
        final list = LayoutBuilder(
          builder: (context, box) {
            final side = box.maxWidth > 650 ? (box.maxWidth - 620) / 2 : 16.0;
            return RefreshIndicator(
              onRefresh: _model.refresh,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (main)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, 8, side, 8),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CommunityStories(
                              entries: _model.stories,
                              repository: widget.repository,
                              loadAvatar: widget.identity.avatar,
                              identity: widget.identity.profile?.identity,
                              error: _model.storiesError,
                              retry: _model.refresh,
                            ),
                            const SizedBox(height: 12),
                            CommunityFeedTabs(
                              mode: _model.mode,
                              onSelected: (value) {
                                if (_scroll.hasClients) _scroll.jumpTo(0);
                                unawaited(_model.select(value));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_model.loading && _model.items.isEmpty)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: side),
                      sliver: const SliverToBoxAdapter(
                        child: CommunityFeedSkeleton(),
                      ),
                    ),
                  if (!_model.loading &&
                      _model.items.isEmpty &&
                      _model.error == null)
                    SliverToBoxAdapter(
                      child: ContentState(
                        title: switch (widget.path) {
                          'saved' => 'No saved posts',
                          'archive' => 'Your archive is empty',
                          _ =>
                            _model.mode == 'following'
                                ? 'No posts from your circle yet'
                                : 'A quiet moment on campus',
                        },
                        message: switch (widget.path) {
                          'saved' => 'Save a post to revisit it here.',
                          'archive' => 'Archived posts appear here until you restore or delete them.',
                          _ =>
                            _model.mode == 'following'
                                ? 'Follow members to see their latest posts here.'
                                : 'New community posts will appear here.',
                        },
                        icon: widget.path == 'saved'
                            ? Icons.bookmark_border
                            : Icons.landscape_outlined,
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    sliver: SliverList.builder(
                      itemCount: _model.items.length,
                      itemBuilder: (context, index) {
                        final post = _model.items[index];
                        return Padding(
                          key: ValueKey(post.id),
                          padding: const EdgeInsets.only(bottom: 14),
                          child: CommunityPostCard(
                            post: post,
                            repository: widget.repository,
                            loadAvatar: widget.identity.avatar,
                            onExpose: main
                                ? () => unawaited(_model.seen(post))
                                : null,
                            likeBusy: _model.busy(post.id, 'like'),
                            saveBusy: _model.busy(post.id, 'save'),
                            like: () => communityCommand(
                              context,
                              () => _model.toggle(post, 'like'),
                            ),
                            save: () => communityCommand(
                              context,
                              () => _model.toggle(post, 'save'),
                            ),
                            comment: () => communityMenu<void>(
                              context,
                              scrollableSheet: true,
                              child: CommunityComments(
                                repository: widget.repository,
                                post: post,
                                loadAvatar: widget.identity.avatar,
                              ),
                            ),
                            menu: () => communityPostMenu(
                              context,
                              widget.repository,
                              post,
                            ),
                            share: () => shareCommunityPost(context, post),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_model.error case final error?)
                    SliverToBoxAdapter(
                      child: ContentState(
                        compact: true,
                        title: error is CommunityFailure && error.offline
                            ? 'You’re offline'
                            : 'Couldn’t load posts',
                        message: error is CommunityFailure
                            ? error.message
                            : 'Try again in a moment.',
                        icon: Icons.cloud_off_outlined,
                        onRetry: () => _model.refresh(clear: true),
                      ),
                    ),
                  if (_model.loadingMore)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  if (!_model.loading &&
                      !_model.loadingMore &&
                      _model.next != null &&
                      _model.error == null)
                    SliverToBoxAdapter(
                      child: Center(
                        child: TextButton(
                          onPressed: _model.more,
                          child: const Text('Load more posts'),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            );
          },
        );
        return main
            ? list
            : Scaffold(
                appBar: AppBar(title: Text(widget.title ?? 'Community')),
                backgroundColor: theme.scaffoldBackgroundColor,
                body: list,
              );
      },
    ),
  );
}

class CommunityFeedTabs extends StatelessWidget {
  const CommunityFeedTabs({
    super.key,
    required this.mode,
    required this.onSelected,
  });
  final String mode;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          for (final (value, label) in [
            ('for-you', 'For you'),
            ('following', 'Following'),
          ])
            Expanded(
              child: Semantics(
                selected: mode == value,
                child: TextButton(
                  onPressed: () => onSelected(value),
                  style: TextButton.styleFrom(
                    foregroundColor: mode == value
                        ? colors.primary
                        : colors.onSurfaceVariant,
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: mode == value
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(label),
                      ),
                      if (mode == value)
                        Positioned(
                          bottom: 1,
                          left: 5,
                          right: 5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const SizedBox(height: 2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CommunityFeedSkeleton extends StatelessWidget {
  const CommunityFeedSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const SkeletonGroup(
    label: 'Loading community feed',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SkeletonAvatar(size: 40),
            SizedBox(width: 12),
            SkeletonText(width: 142),
          ],
        ),
        SizedBox(height: 12),
        SkeletonImage(aspectRatio: 1.48),
        SizedBox(height: 14),
        SkeletonText(width: 200),
        SizedBox(height: 16),
      ],
    ),
  );
}

class CommunityProfileGrid extends StatefulWidget {
  const CommunityProfileGrid({
    super.key,
    required this.repository,
    required this.userId,
    required this.own,
    required this.locked,
  });
  final CommunityRepository repository;
  final String userId;
  final bool own, locked;
  @override
  State<CommunityProfileGrid> createState() => _CommunityProfileGridState();
}

class _CommunityProfileGridState extends State<CommunityProfileGrid> {
  late CommunityFeedModel model;
  void _initialize() {
    model = CommunityFeedModel(
      widget.repository,
      path: 'profiles/${widget.userId}/posts',
    );
    if (!widget.locked) unawaited(model.refresh());
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(CommunityProfileGrid old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId || old.locked != widget.locked) {
      model.dispose();
      _initialize();
    }
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      if (widget.locked) {
        return const ContentState(
          title: 'Private account',
          message: 'Follow this member to see their posts.',
          icon: Icons.lock_outline,
          compact: true,
        );
      }
      final showGrid = model.items.isNotEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.own) const CommunityCollectionLinks(),
          if (model.error != null)
            ContentState(
              title: 'Posts unavailable',
              message: 'Try reloading this profile.',
              onRetry: model.refresh,
              compact: true,
            )
          else if (model.loading)
            const SkeletonGroup(
              label: 'Loading profile posts',
              child: SkeletonImage(aspectRatio: 2.5),
            )
          else if (!showGrid)
            const ContentState(
              title: 'No posts yet',
              message: 'New photos will appear here.',
              icon: Icons.photo_library_outlined,
              compact: true,
            ),
          if (showGrid)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: model.items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (context, i) {
                final post = model.items[i];
                return Semantics(
                  button: true,
                  label: 'Open post ${i + 1}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Material(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (post.media.isNotEmpty)
                            CommunityMedia(
                              repository: widget.repository,
                              image: post.media.first,
                            ),
                          if (post.media.length > 1)
                            const Positioned(
                              right: 6,
                              top: 6,
                              child: Icon(
                                Icons.collections_rounded,
                                color: Colors.white,
                                size: 18,
                                shadows: [Shadow(blurRadius: 8)],
                              ),
                            ),
                          Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              onTap: () => context.push('/posts/${post.id}'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          if (model.next != null)
            TextButton(
              onPressed: model.loadingMore ? null : model.more,
              child: Text(model.loadingMore ? 'Loading…' : 'Load more posts'),
            ),
        ],
      );
    },
  );
}

class CommunityCollectionLinks extends StatelessWidget {
  const CommunityCollectionLinks({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Wrap(
      spacing: 8,
      children: [
        for (final (label, icon, path) in [
          ('Saved', Icons.bookmark_outline_rounded, '/community/saved'),
          ('Archive', Icons.archive_outlined, '/community/archive'),
        ])
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerLow,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: () => context.push(path),
            icon: Icon(icon, size: 18),
            label: Text(label),
          ),
      ],
    ),
  );
}
