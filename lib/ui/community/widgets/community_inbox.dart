import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/community.dart';
import '../../core/ui/avatars/member_avatar.dart';
import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/loading/skeleton.dart';
import '../view_models/community_inbox_model.dart';
import 'community_actions.dart';
import 'community_author.dart';
import 'community_media.dart';

class CommunityInboxScreen extends StatelessWidget {
  const CommunityInboxScreen({
    super.key,
    required this.model,
    required this.loadAvatar,
  });
  final CommunityInboxModel model;
  final CommunityAvatarLoader loadAvatar;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final now = DateTime.now();
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: const Text('Activity'),
          actions: [
            if (model.unread > 0)
              TextButton(
                onPressed: () =>
                    communityCommand(context, () => model.mark(null)),
                child: const Text('Mark all read'),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: RefreshIndicator(
                onRefresh: model.refresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: model.items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == model.items.length) {
                      return Column(
                        children: [
                          if (model.loading && model.items.isEmpty)
                            const ActivitySkeleton()
                          else if (model.loadingMore)
                            const LinearProgressIndicator(),
                          if (model.error != null)
                            ContentState(
                              title: 'Couldn’t refresh activity',
                              message: model.error.toString(),
                              onRetry: model.refresh,
                              compact: true,
                            ),
                          if (model.items.isEmpty &&
                              !model.loading &&
                              model.error == null)
                            const ContentState(
                              title: 'You’re all caught up',
                              message: 'Likes, comments and follow requests will appear here.',
                              icon: Icons.notifications_none,
                            ),
                          if (model.next != null)
                            TextButton(
                              onPressed: model.loadingMore ? null : model.more,
                              child: const Text('Load more activity'),
                            ),
                        ],
                      );
                    }
                    final activity = model.items[index];
                    final group = _group(activity.time, now);
                    final sectionStart =
                        index == 0 ||
                        _group(model.items[index - 1].time, now) != group;
                    return Column(
                      key: ValueKey(activity.id),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (sectionStart)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 15, 4, 7),
                            child: Semantics(
                              header: true,
                              child: Text(
                                group,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ),
                        CommunityActivityRow(
                          activity: activity,
                          model: model,
                          loadAvatar: loadAvatar,
                          onOpen: () async {
                            final path = activity.conversationId != null
                                ? '/messages/${activity.conversationId}'
                                : activity.kind == 'follow_request'
                                ? '/community/requests'
                                : activity.entryId == null
                                ? '/members/${activity.actor.id}'
                                : activity.kind == 'story_like'
                                ? '/community/stories/${activity.entryId}'
                                : '/posts/${activity.entryId}';
                            if (!activity.read) {
                              await communityCommand(
                                context,
                                () => model.mark(activity.id),
                              );
                            }
                            if (context.mounted) context.push(path);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  static String _group(DateTime value, DateTime now) {
    final day = value.toLocal();
    if (DateUtils.isSameDay(day, now)) return 'Today';
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (DateUtils.isSameDay(day, yesterday)) return 'Yesterday';
    return 'Earlier';
  }
}

class CommunityActivityRow extends StatelessWidget {
  const CommunityActivityRow({
    super.key,
    required this.activity,
    required this.model,
    required this.loadAvatar,
    required this.onOpen,
  });

  final CommunityActivity activity;
  final CommunityInboxModel model;
  final CommunityAvatarLoader loadAvatar;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, action) = switch (activity.kind) {
      'like' => (Icons.favorite_rounded, 'liked your post'),
      'story_like' => (Icons.favorite_rounded, 'liked your story'),
      'comment' => (
        Icons.chat_bubble_outline_rounded,
        'commented on your post',
      ),
      'reply' => (Icons.reply_rounded, 'replied to your comment'),
      'mention' => (Icons.alternate_email_rounded, 'mentioned you'),
      'follow' => (Icons.person_add_alt_1_rounded, 'followed you'),
      'follow_request' => (
        Icons.person_add_alt_1_rounded,
        'requested to follow you',
      ),
      'follow_accepted' => (
        Icons.person_outline_rounded,
        'accepted your request',
      ),
      'comment_like' => (Icons.favorite_rounded, 'liked your comment'),
      'message_request' => (Icons.forum_outlined, 'sent a message request'),
      'group_invite' => (
        Icons.group_add_outlined,
        'invited you to a private group',
      ),
      'group_membership' => (Icons.groups_outlined, 'updated a private group'),
      'chat_mention' => (
        Icons.alternate_email_rounded,
        'mentioned you in a chat',
      ),
      'chat_reply' => (Icons.reply_rounded, 'replied to your message'),
      'shared_post' => (Icons.photo_library_outlined, 'shared a campus post'),
      'story_reply' => (Icons.reply_rounded, 'replied to your story'),
      _ => (Icons.notifications_none_rounded, 'interacted with your content'),
    };
    final others = activity.events - 1;
    final name = switch (others) {
      <= 0 => activity.actor.displayName,
      1 => '${activity.actor.displayName} and 1 other',
      _ => '${activity.actor.displayName} and $others others',
    };
    final time = activity.time.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: activity.read ? colors.surface : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    10,
                    11,
                    activity.read ? 10 : 0,
                    11,
                  ),
                  child: Row(
                    children: [
                      ActivityActor(
                        activity: activity,
                        loadAvatar: loadAvatar,
                        icon: icon,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(text: ' $action'),
                                ],
                              ),
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              activity.kind == 'follow_request'
                                  ? 'Review requests'
                                  : DateUtils.isSameDay(time, DateTime.now())
                                  ? DateFormat.jm().format(time)
                                  : DateFormat.MMMd().add_jm().format(time),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: activity.kind == 'follow_request'
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (activity.preview case final preview?)
                        Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: SizedBox.square(
                            dimension: 43,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ExcludeSemantics(
                                child: CommunityMedia(
                                  repository: model.repository,
                                  image: preview,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (!activity.read)
              IconButton(
                tooltip: 'Mark as read',
                onPressed: () =>
                    communityCommand(context, () => model.mark(activity.id)),
                icon: Icon(Icons.circle, color: colors.primary, size: 8),
              ),
          ],
        ),
      ),
    );
  }
}

class ActivityActor extends StatelessWidget {
  const ActivityActor({
    super.key,
    required this.activity,
    required this.loadAvatar,
    required this.icon,
  });
  final CommunityActivity activity;
  final CommunityAvatarLoader loadAvatar;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        width: 46,
        height: 47,
        child: Stack(
          children: [
            MemberAvatar(
              identity: activity.actor,
              loadAvatar: loadAvatar,
              size: 41,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(icon, color: colors.primary, size: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivitySkeleton extends StatelessWidget {
  const ActivitySkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    label: 'Loading activity',
    child: Column(
      children: List.generate(
        4,
        (index) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SkeletonAvatar(size: 42),
              SizedBox(width: 12),
              Expanded(child: SkeletonText()),
              SizedBox(width: 18),
            ],
          ),
        ),
      ),
    ),
  );
}
