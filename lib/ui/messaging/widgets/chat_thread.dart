import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/messaging.dart';
import '../../community/widgets/community_actions.dart';
import '../../core/ui/feedback/content_state.dart';
import '../view_models/chat_thread_model.dart';
import 'chat_bubble.dart';
import 'chat_composer.dart';
import 'messaging_inbox.dart';
import 'messaging_scope.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.id,
    this.story,
    this.initialAnchor,
    this.initialSection = 'discussion',
  });
  final String id;
  final String? story;
  final int? initialAnchor;
  final String initialSection;
  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  late final ChatThreadModel model;
  final scroll = ScrollController();
  final text = TextEditingController();
  final focus = FocusNode();
  String? _draftBeforeEditing;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    model = ChatThreadModel(
      MessagingScope.of(context, listen: false).session,
      widget.id,
      referenceId: widget.story,
      referenceKind: widget.story == null ? null : 'story',
      section: widget.initialSection,
    );
    model.addListener(_position);
    scroll.addListener(_scroll);
    unawaited(model.load(at: widget.initialAnchor));
  }

  void _position() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ModalRoute.isCurrentOf(context) == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          (!scroll.hasClients || scroll.offset < 230)) {
        model.markRead();
      }
    });
  }

  void _scroll() {
    if (!scroll.hasClients) return;
    if (scroll.offset < 90) _position();
    if (scroll.position.extentAfter < 240 && model.next != null) {
      unawaited(model.load(older: true));
    }
  }

  Future<void> _jump(int seq) async {
    await model.load(at: seq);
    if (mounted && scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> _close() async {
    if (_closing || model.busy) return;
    if (model.photos.isNotEmpty) {
      _closing = true;
      final discard = await communityConfirm(
        context,
        'Discard attachments?',
        'The selected photos will be removed from this draft.',
      );
      _closing = false;
      if (!mounted || !discard) return;
      for (final photo in [...model.photos]) {
        model.removePhoto(photo);
      }
    }
    if (mounted) context.pop();
  }

  Future<void> _send() async {
    final wasEditing = model.editing != null;
    if (await model.send(text.text) && mounted) {
      text.text = wasEditing ? (_draftBeforeEditing ?? '') : '';
      _draftBeforeEditing = null;
      if (scroll.hasClients) scroll.jumpTo(0);
    }
  }

  void _clear() {
    if (model.editing != null) {
      text.text = _draftBeforeEditing ?? '';
      _draftBeforeEditing = null;
    }
    model.setReply(null);
    model.clearReference();
  }

  Future<void> _showSection(String section) async {
    if (section == model.section || model.busy || model.picking) return;
    if ((text.text.trim().isNotEmpty || model.photos.isNotEmpty) &&
        !await communityConfirm(
          context,
          'Discard this draft?',
          'Your draft belongs to the current section.',
        )) {
      return;
    }
    if (!mounted) return;
    focus.unfocus();
    text.clear();
    _draftBeforeEditing = null;
    for (final photo in [...model.photos]) {
      model.removePhoto(photo);
    }
    await model.showSection(section);
    if (mounted && scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> _options(ChatMessage message, Conversation thread) async {
    final own = message.senderId == model.session.repository.userId;
    final selection = await communityMenu<String>(
      context,
      child: ChatMessageMenu(message: message, thread: thread, own: own),
    );
    if (!mounted || selection == null) return;
    if (selection.startsWith('react:')) {
      await communityCommand(
        context,
        () => model.action(message, 'react', selection.substring(6)),
      );
      return;
    }
    switch (selection) {
      case 'reply':
        model.setReply(message);
        focus.requestFocus();
      case 'copy':
        await Clipboard.setData(ClipboardData(text: message.body));
        if (mounted) communityFeedback(context, 'Copied');
      case 'edit':
        _draftBeforeEditing = text.text;
        model.edit(message);
        text.text = message.body;
        focus.requestFocus();
      case 'forward':
        context.push('/messages/forward/${message.id}');
      case 'report':
        await openChatReport(
          context,
          thread.id,
          message.announcement ? 'announcement' : 'message',
          subject: message.id,
        );
      case 'delete':
        if (await communityConfirm(
              context,
              'Remove for everyone?',
              'The message disappears for all members.',
            ) &&
            mounted) {
          await communityCommand(
            context,
            () => model.action(message, 'delete', null),
          );
        }
      case 'hide':
        await communityCommand(
          context,
          () => model.action(message, 'hide', null),
        );
      case 'pin':
        await communityCommand(
          context,
          () => model.action(message, 'pin', !message.pinned),
        );
    }
  }

  Future<void> _request(Conversation thread, bool accept) async {
    await communityCommand(context, () async {
      final path = thread.invited
          ? 'groups/${thread.id}/invitation'
          : 'conversations/${thread.id}/request';
      await model.session.repository.object(
        path,
        method: 'PUT',
        data: {'accept': accept},
      );
      if (!mounted) return;
      if (!accept) {
        context.pop();
        return;
      }
      await model.load();
    });
  }

  @override
  void dispose() {
    model.removeListener(_position);
    model.dispose();
    scroll.dispose();
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final thread = model.conversation;
      final colors = Theme.of(context).colorScheme;
      final synced = model.session.snapshot;
      final inFocus = model.session.focusedThread == widget.id;
      return PopScope(
        canPop: !model.busy && model.photos.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_close());
        },
        child: Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: model.busy ? null : _close,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: thread == null
                ? const Text('Conversation')
                : ConversationHeader(
                    thread: thread,
                    subtitle: inFocus
                        ? synced?.typing.isNotEmpty == true
                              ? (thread.group
                                    ? '${synced!.typing.length} typing…'
                                    : '${thread.peer?.displayName.split(' ').first ?? 'Member'} is typing…')
                              : synced?.online == true
                              ? 'Active now'
                              : synced?.lastSeen != null
                              ? 'Last seen ${DateFormat.MMMd().add_jm().format(synced!.lastSeen!)}'
                              : null
                        : null,
                    onOpen: () => context.push('/messages/${thread.id}/info'),
                  ),
            actions: [
              if (thread != null && !thread.invited)
                IconButton(
                  tooltip: 'Search messages',
                  onPressed: () async {
                    final result = await context.push<int>(
                      '/messages/${thread.id}/search${thread.academic ? '?section=${model.section}' : ''}',
                    );
                    if (result != null && mounted) await _jump(result);
                  },
                  icon: const Icon(Icons.search_rounded),
                ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  if (thread?.academic == true)
                    AcademicThreadNavigation(
                      announcement: model.announcements,
                      study: thread!.study,
                      onSection: _showSection,
                      onStudy: () =>
                          context.push('/messages/${thread.id}/study'),
                    ),
                  if (thread != null && model.anchor == null)
                    if (model.messages.where((m) => m.pinned).firstOrNull
                        case final pinned?)
                      ChatPinnedJump(
                        message: pinned,
                        onTap: () => _jump(pinned.seq),
                      ),
                  if (model.session.reconnecting)
                    const MessagingStatus(
                      text: 'Reconnecting to messages',
                      icon: Icons.wifi_off_rounded,
                    ),
                  if (model.anchor != null)
                    TextButton.icon(
                      onPressed: model.live,
                      icon: const Icon(Icons.south_rounded),
                      label: const Text('Back to latest'),
                    ),
                  Expanded(
                    child: thread == null
                        ? (model.loading
                              ? const MessagingSkeleton()
                              : ContentState(
                                  title: 'Conversation unavailable',
                                  message: model.error?.toString() ?? 'Open an accessible conversation from Messages.',
                                  onRetry: model.load,
                                  icon: Icons.lock_outline_rounded,
                                ))
                        : thread.invited
                        ? RequestPanel(
                            thread: thread,
                            onRespond: (accept) => _request(thread, accept),
                          )
                        : ChatMessagesList(
                            model: model,
                            thread: thread,
                            scroll: scroll,
                            onOptions: (message) => _options(message, thread),
                            onJump: _jump,
                            onReaction: (message, value) => communityCommand(
                              context,
                              () => model.action(
                                message,
                                'react',
                                value.isEmpty ? null : value,
                              ),
                            ),
                          ),
                  ),
                  if (thread != null && !thread.invited)
                    if (model.announcements
                        ? thread.academic && thread.admin
                        : thread.canWrite)
                      ChatComposer(
                        model: model,
                        text: text,
                        focus: focus,
                        onSend: _send,
                        onClear: _clear,
                      )
                    else if (thread.pending && !thread.initiated)
                      RequestPanel(
                        thread: thread,
                        onRespond: (accept) => _request(thread, accept),
                        compact: true,
                      )
                    else
                      SafeArea(
                        top: false,
                        child: MessagingStatus(
                          text: thread.pending
                              ? 'Waiting for the member to accept'
                              : model.announcements
                              ? 'Only administrators can publish announcements'
                              : thread.sendPolicy == 'locked'
                              ? 'Discussion is locked'
                              : 'Only administrators can write here',
                          icon: Icons.lock_outline_rounded,
                        ),
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

class ConversationHeader extends StatelessWidget {
  const ConversationHeader({
    super.key,
    required this.thread,
    required this.onOpen,
    this.subtitle,
  });
  final Conversation thread;
  final VoidCallback onOpen;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          ConversationAvatar(thread: thread, size: 36),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        thread.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (thread.official)
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                          semanticLabel: 'Verified department',
                        ),
                      ),
                  ],
                ),
                Text(
                  subtitle ??
                      (thread.official
                          ? thread.departmentName ?? 'Official channel'
                          : thread.study
                          ? [
                              thread.courseCode,
                              thread.courseName,
                            ].nonNulls.join(' · ')
                          : thread.group
                          ? '${thread.memberCount} members'
                          : 'Conversation info'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class AcademicThreadNavigation extends StatelessWidget {
  const AcademicThreadNavigation({
    super.key,
    required this.announcement,
    required this.study,
    required this.onSection,
    required this.onStudy,
  });
  final bool announcement, study;
  final ValueChanged<String> onSection;
  final VoidCallback onStudy;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 3,
        children: [
          for (final (label, key, chosen) in [
            ('Announcements', 'announcement', announcement),
            ('Discussion', 'discussion', !announcement),
          ])
            ChoiceChip(
              label: Text(label),
              selected: chosen,
              showCheckmark: false,
              selectedColor: colors.primaryContainer,
              labelStyle: TextStyle(
                color: chosen
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
              onSelected: (_) => onSection(key),
            ),
          if (study)
            ActionChip(
              avatar: const Icon(Icons.auto_stories_outlined, size: 17),
              label: const Text('Study tools'),
              onPressed: onStudy,
            ),
        ],
      ),
    );
  }
}

class ChatPinnedJump extends StatelessWidget {
  const ChatPinnedJump({super.key, required this.message, required this.onTap});
  final ChatMessage message;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: ChatContextStrip(
      icon: Icons.push_pin_outlined,
      title: message.body.isEmpty ? 'Pinned attachment' : message.body,
      onTap: onTap,
    ),
  );
}

class ChatMessagesList extends StatelessWidget {
  const ChatMessagesList({
    super.key,
    required this.model,
    required this.thread,
    required this.scroll,
    required this.onOptions,
    required this.onJump,
    required this.onReaction,
  });
  final ChatThreadModel model;
  final Conversation thread;
  final ScrollController scroll;
  final ValueChanged<ChatMessage> onOptions;
  final ValueChanged<int> onJump;
  final void Function(ChatMessage, String) onReaction;

  static bool _near(ChatMessage? a, ChatMessage b) =>
      a != null &&
      a.senderId == b.senderId &&
      a.systemEvent == null &&
      (a.at.difference(b.at).inSeconds).abs() < 120 &&
      DateUtils.isSameDay(a.at, b.at);

  @override
  Widget build(BuildContext context) {
    final items = model.messages;
    final user = model.session.repository.userId;
    if (items.isEmpty) {
      if (model.loading) return const MessagingSkeleton();
      final (heading, detail, icon) = model.announcements
          ? (
              'No announcements yet',
              'Department and room updates will appear here.',
              Icons.campaign_outlined,
            )
          : thread.academic && !thread.canWrite
          ? (
              'No discussion yet',
              'Messages will appear here when members with permission post.',
              Icons.forum_outlined,
            )
          : (
              'Start the conversation',
              'Send a message to get started.',
              Icons.chat_bubble_outline_rounded,
            );
      return ContentState(
        title: model.error == null ? heading : 'Could not load messages',
        message: model.error?.toString() ?? detail,
        onRetry: model.error == null ? null : model.load,
        icon: icon,
      );
    }
    return ListView.builder(
      reverse: true,
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        if (i == items.length) {
          if (model.loadingMore) return const LinearProgressIndicator();
          if (model.error != null) {
            return ContentState(
              title: 'Could not refresh messages',
              message: model.error.toString(),
              onRetry: model.load,
              compact: true,
            );
          }
          return model.next == null
              ? const SizedBox.shrink()
              : Center(
                  child: TextButton(
                    onPressed: () => model.load(older: true),
                    child: const Text('Older messages'),
                  ),
                );
        }
        final value = items[i],
            earlier = i + 1 < items.length ? items[i + 1] : null,
            later = i > 0 ? items[i - 1] : null;
        final boundary = model.unreadBoundary;
        return Column(
          key: ValueKey(value.id),
          children: [
            if (earlier == null || !DateUtils.isSameDay(value.at, earlier.at))
              ChatDivider(
                label: DateUtils.isSameDay(value.at, DateTime.now())
                    ? 'Today'
                    : DateFormat.MMMEd().format(value.at),
              ),
            if (boundary != null &&
                value.seq > boundary &&
                (earlier == null || earlier.seq <= boundary))
              const ChatDivider(label: 'Unread messages', highlight: true),
            ChatBubble(
              message: value,
              thread: thread,
              mine: value.senderId == user,
              start: !_near(earlier, value),
              end: !_near(later, value),
              onOptions: () => onOptions(value),
              onReply: onJump,
              onReaction: (emoji) => onReaction(value, emoji),
            ),
          ],
        );
      },
    );
  }
}

class RequestPanel extends StatelessWidget {
  const RequestPanel({
    super.key,
    required this.thread,
    required this.onRespond,
    this.compact = false,
  });
  final Conversation thread;
  final ValueChanged<bool> onRespond;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Center(
          heightFactor: compact ? 1 : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ...[
                ConversationAvatar(thread: thread, size: 60),
                const SizedBox(height: 12),
                Text(
                  'Private group invitation',
                  style: theme.textTheme.titleLarge,
                ),
                if (thread.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      thread.description,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ] else
                Text(
                  'Accept this request to reply and exchange photos.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => onRespond(false),
                    child: const Text('Decline'),
                  ),
                  FilledButton(
                    onPressed: () => onRespond(true),
                    child: Text(
                      thread.invited ? 'Join group' : 'Accept request',
                    ),
                  ),
                  TextButton(
                    onPressed: () => openChatReport(
                      context,
                      thread.id,
                      thread.invited ? 'group_invitation' : 'message_request',
                    ),
                    child: const Text('Report'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatMessageMenu extends StatelessWidget {
  const ChatMessageMenu({
    super.key,
    required this.message,
    required this.thread,
    required this.own,
  });
  final ChatMessage message;
  final Conversation thread;
  final bool own;
  @override
  Widget build(BuildContext context) => CommunityMenuBody(
    title: 'Message',
    children: [
      if (!thread.pending)
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final emoji in ['❤️', '👍', '😂', '🎉', '😮', '🙏'])
              IconButton(
                tooltip: switch (emoji) {
                  '❤️' => 'React with heart',
                  '👍' => 'React with thumbs up',
                  '😂' => 'React with laughter',
                  '🎉' => 'React with celebration',
                  '😮' => 'React with surprise',
                  _ => 'React with thanks',
                },
                onPressed: () => Navigator.pop(context, 'react:$emoji'),
                icon: ExcludeSemantics(
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
      if ((message.announcement ? thread.admin : thread.canWrite) &&
          !thread.pending)
        const CommunityMenuOption('Reply', Icons.reply_rounded, 'reply'),
      if (message.body.isNotEmpty)
        const CommunityMenuOption('Copy text', Icons.copy_rounded, 'copy'),
      if (!thread.pending &&
          message.referenceKind != 'story' &&
          (message.body.isNotEmpty || message.referenceId != null))
        const CommunityMenuOption('Forward', Icons.forward_outlined, 'forward'),
      if ((message.announcement
              ? thread.admin
              : own && message.withinEditWindow) &&
          message.body.isNotEmpty &&
          !thread.pending)
        const CommunityMenuOption('Edit message', Icons.edit_outlined, 'edit'),
      if (thread.group &&
          (thread.admin ||
              !message.announcement && thread.pinPolicy == 'members'))
        CommunityMenuOption(
          message.pinned ? 'Unpin message' : 'Pin message',
          Icons.push_pin_outlined,
          'pin',
        ),
      if (!thread.pending &&
          (thread.group && thread.admin ||
              !message.announcement && own && message.withinEditWindow))
        const CommunityMenuOption(
          'Remove for everyone',
          Icons.delete_forever_outlined,
          'delete',
        ),
      const CommunityMenuOption(
        'Remove for me',
        Icons.hide_source_outlined,
        'hide',
      ),
      if (!own)
        const CommunityMenuOption(
          'Report message',
          Icons.flag_outlined,
          'report',
        ),
    ],
  );
}

Future<void> openChatReport(
  BuildContext context,
  String thread,
  String kind, {
  String? subject,
}) async {
  final scope = MessagingScope.of(context, listen: false);
  final result = await communityMenu<String>(
    context,
    child: const CommunityMenuBody(
      title: 'Report privately',
      children: [
        CommunityMenuOption('Harassment', Icons.shield_outlined, 'harassment'),
        CommunityMenuOption('Spam', Icons.report_outlined, 'spam'),
        CommunityMenuOption(
          'Unsafe content',
          Icons.warning_amber_rounded,
          'unsafe',
        ),
        CommunityMenuOption('Privacy concern', Icons.lock_outline, 'privacy'),
        CommunityMenuOption('Something else', Icons.flag_outlined, 'other'),
      ],
    ),
  );
  if (result == null || !context.mounted) return;
  await communityCommand(context, () async {
    await scope.session.repository.object(
      'conversations/$thread/reports',
      method: 'POST',
      data: {'kind': kind, 'subject': subject, 'category': result},
    );
  }, success: 'Report received');
}
