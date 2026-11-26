import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/messaging.dart';
import '../../community/widgets/community_media.dart';
import '../../core/ui/avatars/member_avatar.dart';
import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/loading/skeleton.dart';
import '../view_models/messaging_session.dart';
import 'messaging_scope.dart';

class MessagingInbox extends StatefulWidget {
  const MessagingInbox({super.key});
  @override
  State<MessagingInbox> createState() => _MessagingInboxState();
}

class _MessagingInboxState extends State<MessagingInbox> {
  late final MessagingSession session;
  final search = TextEditingController();
  final scroll = ScrollController();
  List<Conversation> rows = const [];
  String mode = 'inbox';
  String? next, version;
  Object? error;
  bool loading = true, more = false;
  int generation = 0;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    session = MessagingScope.of(context, listen: false).session;
    session.addListener(_changed);
    scroll.addListener(_nearEnd);
    unawaited(load());
  }

  void _changed() {
    final current = session.snapshot?.version;
    if (current != null && current != version) {
      version = current;
      if (!loading && !more) unawaited(load());
    }
  }

  void _nearEnd() {
    if (scroll.hasClients &&
        scroll.position.extentAfter < 320 &&
        next != null &&
        error == null) {
      unawaited(load(append: true));
    }
  }

  Future<void> load({bool append = false}) async {
    if (append && (loading || more || next == null)) return;
    final current = ++generation;
    final cursor = append ? next : null;
    setState(() {
      loading = !append;
      more = append;
      error = null;
    });
    try {
      final result = await session.repository.conversations(
        mode: mode,
        cursor: cursor,
        search: search.text.trim(),
      );
      if (!mounted || current != generation) return;
      setState(() {
        rows = {
          if (append)
            for (final item in rows) item.id: item,
          for (final item in result.items) item.id: item,
        }.values.toList();
        next = result.next;
      });
    } catch (e) {
      if (mounted && current == generation) setState(() => error = e);
    } finally {
      if (mounted && current == generation) {
        setState(() => loading = more = false);
      }
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    session.removeListener(_changed);
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sync = MessagingScope.of(context).session;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Messaging privacy',
            onPressed: () => context.push('/messages/privacy'),
            icon: const Icon(Icons.tune_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filled(
              tooltip: 'New conversation',
              onPressed: () => context.push('/messages/new'),
              style: IconButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
              ),
              icon: const Icon(Icons.edit_outlined, size: 21),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: MessagingSearch(
                    controller: search,
                    label: 'Search conversations',
                    onChanged: (_) {
                      debounce?.cancel();
                      debounce = Timer(
                        const Duration(milliseconds: 300),
                        () => unawaited(load()),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 12, 4),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 5,
                    children: [
                      for (final (value, label) in [
                        ('inbox', 'Inbox'),
                        ('requests', 'Requests'),
                        ('archived', 'Archive'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: mode == value,
                          showCheckmark: false,
                          selectedColor: colors.primaryContainer,
                          backgroundColor: colors.surfaceContainerLow,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          labelStyle: TextStyle(
                            color: mode == value
                                ? colors.onPrimaryContainer
                                : colors.onSurfaceVariant,
                          ),
                          onSelected: (_) {
                            if (value == mode) return;
                            rows = const [];
                            next = null;
                            mode = value;
                            if (scroll.hasClients) scroll.jumpTo(0);
                            unawaited(load());
                          },
                        ),
                    ],
                  ),
                ),
                if (sync.reconnecting)
                  const MessagingStatus(
                    text: 'Reconnecting',
                    icon: Icons.wifi_off_rounded,
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: load,
                    child: ListView.builder(
                      controller: scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 20),
                      itemCount: rows.length + 1,
                      itemBuilder: (context, index) {
                        if (index < rows.length) {
                          final thread = rows[index];
                          return ConversationRow(
                            key: ValueKey(thread.id),
                            thread: thread,
                            onTap: () async {
                              await context.push<void>(
                                '/messages/${thread.id}',
                              );
                              if (mounted) await load();
                            },
                          );
                        }
                        if (loading && rows.isEmpty) {
                          return const MessagingSkeleton();
                        }
                        if (error != null) {
                          return ContentState(
                            title: 'Messages unavailable',
                            message: error.toString(),
                            onRetry: load,
                            compact: true,
                          );
                        }
                        if (rows.isEmpty) {
                          return ContentState(
                            title: search.text.trim().isNotEmpty
                                ? 'No matches'
                                : switch (mode) {
                                    'requests' => 'No message requests',
                                    'archived' => 'No archived conversations',
                                    _ => 'Your inbox is quiet',
                                  },
                            message:
                                mode == 'inbox' && search.text.trim().isEmpty
                                ? 'Start a chat or create a private group.'
                                : 'Conversations in this section will appear here.',
                            icon: Icons.chat_bubble_outline_rounded,
                          );
                        }
                        if (more) return const LinearProgressIndicator();
                        return next != null
                            ? TextButton(
                                onPressed: () => load(append: true),
                                child: const Text('Load more conversations'),
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConversationRow extends StatelessWidget {
  const ConversationRow({super.key, required this.thread, required this.onTap});
  final Conversation thread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unread = thread.unread > 0 || thread.markedUnread || thread.invited;
    final time = DateUtils.isSameDay(thread.activity, DateTime.now())
        ? DateFormat.jm().format(thread.activity)
        : DateFormat.MMMd().format(thread.activity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: unread ? colors.surfaceContainerLow : colors.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                ConversationAvatar(thread: thread, size: 46),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        thread.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: unread
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (thread.pinned)
                          Icon(
                            Icons.push_pin_outlined,
                            size: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        if (thread.muted)
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        if (unread)
                          Badge(
                            label: Text(
                              thread.unread > 99
                                  ? '99+'
                                  : '${thread.unread > 0 ? thread.unread : 1}',
                            ),
                            backgroundColor: colors.primary,
                            textColor: colors.onPrimary,
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({super.key, required this.thread, this.size = 42});
  final Conversation thread;
  final double size;
  @override
  Widget build(BuildContext context) {
    final scope = MessagingScope.of(context, listen: false);
    if (!thread.group) {
      return MemberAvatar(
        identity: thread.peer,
        loadAvatar: scope.profiles.avatar,
        size: size,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .33),
        child: thread.image == null
            ? ColoredBox(
                color: colors.primaryContainer,
                child: Icon(
                  Icons.groups_2_outlined,
                  color: colors.onPrimaryContainer,
                  size: size * .52,
                ),
              )
            : CommunityMedia(
                repository: scope.session.repository.media,
                image: thread.image!,
                label: 'Group image',
              ),
      ),
    );
  }
}

class MessagingSearch extends StatelessWidget {
  const MessagingSearch({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLength: 100,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: const Icon(Icons.search_rounded, size: 21),
        counterText: '',
        filled: true,
        fillColor: colors.surfaceContainerLow,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class MessagingStatus extends StatelessWidget {
  const MessagingStatus({super.key, required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: colors.surfaceContainerLow,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class MessagingSkeleton extends StatelessWidget {
  const MessagingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => SkeletonGroup(
    label: 'Loading messages',
    child: Column(
      children: [
        for (var i = 0; i < 5; i++)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                SkeletonAvatar(size: 43),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonText(width: 128),
                      SizedBox(height: 8),
                      SkeletonText(width: 205),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
