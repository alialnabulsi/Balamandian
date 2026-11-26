import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';
import '../../core/ui/feedback/content_state.dart';
import 'community_actions.dart';
import 'community_author.dart';
import 'community_comments.dart';
import 'community_composer.dart';
import 'community_feed.dart';
import 'community_post_card.dart';
import 'community_stories.dart';

class CommunityEntryScreen extends StatefulWidget {
  const CommunityEntryScreen({
    super.key,
    required this.repository,
    required this.id,
    required this.loadAvatar,
    this.edit = false,
    this.story = false,
    this.initialPhoto = 0,
  });
  final CommunityRepository repository;
  final String id;
  final CommunityAvatarLoader loadAvatar;
  final bool edit, story;
  final int initialPhoto;
  @override
  State<CommunityEntryScreen> createState() => _CommunityEntryScreenState();
}

class _CommunityEntryScreenState extends State<CommunityEntryScreen> {
  late Future<CommunityEntry> _request;
  CommunityEntry? _post;
  final Set<String> _pending = {};
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
    if (!widget.edit) widget.repository.addListener(_refresh);
  }

  void _load() {
    final generation = ++_generation;
    _post = null;
    _request = widget.repository.entry(widget.id).then((value) {
      if (mounted && _generation == generation) _post = value;
      return value;
    });
  }

  void _refresh() {
    if (mounted) setState(_load);
  }

  @override
  void dispose() {
    if (!widget.edit) widget.repository.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _toggle(String action) async {
    final post = _post;
    if (post == null || !_pending.add(action)) return;
    final generation = _generation;
    final next = action == 'like' ? !post.liked : !post.saved;
    setState(
      () => _post = action == 'like'
          ? post.withInteraction(liked: next)
          : post.withInteraction(saved: next),
    );
    try {
      await widget.repository.mutate(
        'entries/${post.id}/$action',
        method: next ? 'PUT' : 'DELETE',
      );
    } catch (e) {
      if (mounted && generation == _generation) {
        if (e is CommunityFailure && e.unavailable) {
          _refresh();
        } else if (_post case final current?) {
          setState(
            () => _post = action == 'like'
                ? current.withInteraction(liked: post.liked)
                : current.withInteraction(saved: post.saved),
          );
        }
        communityFeedback(context, e.toString());
      }
    } finally {
      _pending.remove(action);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CommunityEntry>(
    key: ValueKey(_request),
    future: _request,
    builder: (context, snapshot) {
      final post = _post;
      if (snapshot.connectionState == ConnectionState.done &&
          post != null &&
          widget.story &&
          post.isStory) {
        return CommunityStoryViewer(
          repository: widget.repository,
          entries: [post],
          loadAvatar: widget.loadAvatar,
        );
      }
      if (snapshot.connectionState == ConnectionState.done &&
          post != null &&
          widget.edit &&
          post.isOwn &&
          !post.isStory) {
        return CommunityComposer(
          repository: widget.repository,
          story: false,
          previous: post,
        );
      }
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          leading: context.canPop()
              ? null
              : IconButton(
                  tooltip: 'Go to Home',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go('/'),
                ),
          title: Text(widget.story ? 'Story' : 'Post'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: snapshot.connectionState != ConnectionState.done
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CommunityFeedSkeleton(),
                    )
                  : post == null || post.isStory || widget.edit
                  ? ContentState(
                      title: 'Post unavailable',
                      message: snapshot.error is CommunityFailure
                          ? snapshot.error.toString()
                          : 'This content may be private, expired or removed.',
                      icon: Icons.lock_outline,
                      onRetry: _refresh,
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (post.archived)
                          const ListTile(
                            leading: Icon(Icons.archive_outlined),
                            title: Text('Archived post'),
                          ),
                        CommunityPostCard(
                          post: post,
                          repository: widget.repository,
                          loadAvatar: widget.loadAvatar,
                          detail: true,
                          initialPhoto: widget.initialPhoto,
                          likeBusy: _pending.contains('like'),
                          saveBusy: _pending.contains('save'),
                          like: () => unawaited(_toggle('like')),
                          save: () => unawaited(_toggle('save')),
                          comment: () => communityMenu<void>(
                            context,
                            scrollableSheet: true,
                            child: CommunityComments(
                              repository: widget.repository,
                              post: post,
                              loadAvatar: widget.loadAvatar,
                            ),
                          ),
                          menu: () => communityPostMenu(
                            context,
                            widget.repository,
                            post,
                          ),
                          share: () => shareCommunityPost(context, post),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
}
