import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/community.dart';
import '../../../domain/models/messaging.dart';
import '../../community/widgets/community_media.dart';
import '../../core/ui/avatars/member_avatar.dart';
import 'messaging_scope.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.thread,
    required this.mine,
    required this.start,
    required this.end,
    required this.onOptions,
    required this.onReply,
    required this.onReaction,
  });
  final ChatMessage message;
  final Conversation thread;
  final bool mine, start, end;
  final VoidCallback onOptions;
  final ValueChanged<int> onReply;
  final ValueChanged<String> onReaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    if (message.systemEvent case final event?) {
      return ChatDivider(label: event);
    }
    final bg = mine ? colors.primaryContainer : colors.surfaceContainerLow;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(!mine && !start ? 6 : 18),
      topRight: Radius.circular(mine && !start ? 6 : 18),
      bottomLeft: Radius.circular(!mine && end ? 5 : 18),
      bottomRight: Radius.circular(mine && end ? 5 : 18),
    );
    final time = DateFormat.jm().format(message.at);
    final status = !mine
        ? null
        : message.read
        ? (thread.group ? 'Seen by a member' : 'Read')
        : message.delivered
        ? (thread.group ? 'Delivered to a member' : 'Delivered')
        : 'Sent';
    return Padding(
      padding: EdgeInsets.only(top: start ? 8 : 2, bottom: end ? 5 : 1),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (thread.group && !mine)
            SizedBox(
              width: 36,
              child: start
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: MemberAvatar(
                        identity: message.sender,
                        loadAvatar: MessagingScope.of(
                          context,
                          listen: false,
                        ).profiles.avatar,
                        size: 29,
                      ),
                    )
                  : null,
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: message.deleted ? null : onOptions,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: (MediaQuery.sizeOf(context).width * .83).clamp(
                        0.0,
                        420.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(color: bg, borderRadius: radius),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (thread.group &&
                            !mine &&
                            start &&
                            message.sender != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              message.sender!.displayName,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        if (message.deleted)
                          Text(
                            'Message removed',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else ...[
                          if (message.announcement)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                'Announcement',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (message.forwarded)
                            Text(
                              'Forwarded',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          if (message.reply case final reply?)
                            ChatContextStrip(
                              icon: Icons.reply_rounded,
                              title: 'Reply',
                              detail: reply['deleted'] == true
                                  ? 'Message removed'
                                  : (reply['body'] as String).isEmpty
                                  ? 'Photo or shared item'
                                  : reply['body'] as String,
                              onTap: () =>
                                  onReply(int.parse(reply['seq'] as String)),
                            ),
                          if (message.referenceKind case final kind?)
                            ChatReference(
                              kind: kind,
                              id: message.referenceId,
                              preview: message.referencePreview,
                            ),
                          if (message.images.isNotEmpty)
                            ChatImageGallery(images: message.images),
                          if (message.body.isNotEmpty)
                            Text(
                              message.body,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                        ],
                        if (end || message.edited)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 3,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '$time${message.edited ? ' · Edited' : ''}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                if (status != null)
                                  Tooltip(
                                    message: status,
                                    child: Icon(
                                      status == 'Sent'
                                          ? Icons.check_rounded
                                          : Icons.done_all_rounded,
                                      size: 15,
                                      semanticLabel: status,
                                      color: message.read
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (message.reactions.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: [
                      for (final reaction in message.reactions)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          backgroundColor: reaction['mine'] == true
                              ? colors.primaryContainer
                              : colors.surface,
                          label: Text(
                            '${reaction['emoji']} ${reaction['count']}',
                          ),
                          onPressed: () => onReaction(
                            reaction['mine'] == true
                                ? ''
                                : reaction['emoji'] as String,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class ChatDivider extends StatelessWidget {
  const ChatDivider({super.key, required this.label, this.highlight = false});
  final String label;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: highlight
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class ChatContextStrip extends StatelessWidget {
  const ChatContextStrip({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.onTap,
    this.onClear,
  });
  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback? onTap, onClear;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        borderRadius: BorderRadius.circular(9),
        color: colors.surface.withValues(alpha: .55),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(9, 7, onClear == null ? 9 : 0, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colors.primary, size: 17),
                const SizedBox(width: 7),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium,
                      ),
                      if (detail != null)
                        Text(
                          detail!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    tooltip: 'Clear message context',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatReference extends StatelessWidget {
  const ChatReference({
    super.key,
    required this.kind,
    required this.id,
    this.preview,
  });
  final String kind;
  final String? id;
  final CommunityJson? preview;
  @override
  Widget build(BuildContext context) {
    final post = kind == 'post';
    final repository = MessagingScope.of(
      context,
      listen: false,
    ).session.repository.media;
    final title = post ? 'Shared campus post' : 'Story reply';
    final detail = id == null
        ? 'Content unavailable'
        : (preview?['author'] as String?) ??
              (post ? 'Open campus post' : 'Open story');
    final open = id == null
        ? null
        : () => context.push(post ? '/posts/$id' : '/community/stories/$id');
    if (preview?['image'] case final CommunityJson image when id != null) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          onTap: open,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox.square(
                  dimension: 51,
                  child: CommunityMedia(
                    repository: repository,
                    image: CommunityImage.fromJson(image),
                    label: title,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: theme.textTheme.labelMedium),
                    Text(detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ChatContextStrip(
      icon: post ? Icons.collections_outlined : Icons.auto_awesome_outlined,
      title: title,
      detail: detail,
      onTap: open,
    );
  }
}

class ChatImageGallery extends StatelessWidget {
  const ChatImageGallery({super.key, required this.images});
  final List<CommunityImage> images;
  @override
  Widget build(BuildContext context) {
    final session = MessagingScope.of(context).session;
    final media = session.repository.media;
    return LayoutBuilder(
      builder: (context, box) {
        final edge = images.length == 1
            ? box.maxWidth.clamp(70.0, 256.0)
            : ((box.maxWidth - 6) / 2).clamp(56.0, 150.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4, top: 3),
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var i = 0; i < images.length; i++)
                SizedBox(
                  width: edge,
                  height: images.length == 1 ? edge * .77 : edge,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: GestureDetector(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            ChatFullImage(images: images, initial: i),
                      ),
                      child: CommunityMedia(
                        repository: media,
                        image: images[i],
                        label: 'Open photo ${i + 1} of ${images.length}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class ChatFullImage extends StatefulWidget {
  const ChatFullImage({super.key, required this.images, required this.initial});
  final List<CommunityImage> images;
  final int initial;
  @override
  State<ChatFullImage> createState() => _ChatFullImageState();
}

class _ChatFullImageState extends State<ChatFullImage> {
  late final pages = PageController(initialPage: widget.initial);
  late int index = widget.initial;
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = MessagingScope.of(context).session;
    final media = session.repository.media;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            if (session.snapshot?.threadAvailable == false)
              const Center(
                child: Text(
                  'Photo unavailable',
                  style: TextStyle(color: Colors.white),
                ),
              )
            else
              PageView.builder(
                controller: pages,
                itemCount: widget.images.length,
                onPageChanged: (v) => setState(() => index = v),
                itemBuilder: (context, i) => InteractiveViewer(
                  child: CommunityMedia(
                    key: ValueKey(session.snapshot?.threadVersion),
                    repository: media,
                    image: widget.images[i],
                    full: true,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close photo',
                color: Colors.white,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  '${index + 1} / ${widget.images.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
