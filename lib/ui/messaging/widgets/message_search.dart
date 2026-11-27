import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/messaging.dart';
import '../../core/ui/feedback/content_state.dart';
import 'chat_bubble.dart';
import 'messaging_inbox.dart';
import 'messaging_scope.dart';

class MessageSearch extends StatefulWidget {
  const MessageSearch({
    super.key,
    required this.thread,
    this.filter,
    this.section,
  });
  final String thread;
  final String? filter, section;
  @override
  State<MessageSearch> createState() => _MessageSearchState();
}

class _MessageSearchState extends State<MessageSearch> {
  final search = TextEditingController();
  Timer? debounce;
  List<ChatMessage> matches = [];
  String? next;
  bool busy = false;
  Object? error;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.filter != null) unawaited(_load());
  }

  Future<void> _load({bool more = false}) async {
    final query = search.text.trim();
    final view = ++generation;
    if (query.isEmpty && widget.filter == null) {
      setState(() {
        matches = [];
        next = null;
        error = null;
        busy = false;
      });
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final page = await MessagingScope.of(context, listen: false)
          .session
          .repository
          .history(
            widget.thread,
            before: more ? next : null,
            search: query,
            filter: widget.filter,
            section: widget.section,
          );
      if (mounted && view == generation) {
        setState(() {
          matches = [if (more) ...matches, ...page.page.items];
          next = page.page.next;
        });
      }
    } catch (e) {
      if (mounted && view == generation) {
        setState(() {
          matches = [];
          next = null;
          error = e;
        });
      }
    } finally {
      if (mounted && view == generation) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = MessagingScope.of(context).session;
    final unavailable =
        session.focusedThread == widget.thread &&
        session.snapshot?.threadAvailable == false;
    final title = switch (widget.filter) {
      'images' => 'Shared photos',
      'shares' => 'Shared posts and stories',
      'pinned' => 'Pinned messages',
      'links' => 'Shared links',
      _ => 'Search messages',
    };
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: unavailable
            ? const ContentState(
                title: 'Conversation unavailable',
                message:
                    'This conversation is no longer available to your account.',
                icon: Icons.lock_outline,
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  MessagingSearch(
                    controller: search,
                    label: 'Search by words',
                    onChanged: (_) {
                      generation++;
                      debounce?.cancel();
                      debounce = Timer(
                        const Duration(milliseconds: 320),
                        () => unawaited(_load()),
                      );
                    },
                  ),
                  if (busy) const LinearProgressIndicator(),
                  if (error != null)
                    ContentState(
                      title: 'Could not load messages',
                      message: error.toString(),
                      onRetry: _load,
                      compact: true,
                    ),
                  if (!busy &&
                      error == null &&
                      matches.isEmpty &&
                      (search.text.isNotEmpty || widget.filter != null))
                    const ContentState(
                      title: 'No matching messages',
                      message:
                          'Try another word or search the full conversation.',
                      icon: Icons.search_off_rounded,
                      compact: true,
                    ),
                  for (final message in matches)
                    MessageSearchRow(
                      message: message,
                      onJump: () => context.pop(message.seq),
                      gallery: widget.filter,
                    ),
                  if (next != null)
                    TextButton(
                      onPressed: busy ? null : () => _load(more: true),
                      child: const Text('More results'),
                    ),
                ],
              ),
      ),
    );
  }
}

class MessageSearchRow extends StatelessWidget {
  const MessageSearchRow({
    super.key,
    required this.message,
    required this.onJump,
    this.gallery,
  });
  final ChatMessage message;
  final VoidCallback onJump;
  final String? gallery;
  @override
  Widget build(BuildContext context) {
    if (gallery == 'images' && message.images.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(
              onPressed: onJump,
              child: Text(
                '${message.sender?.displayName ?? 'Member'} · ${DateFormat.MMMd().format(message.at)}',
              ),
            ),
            ChatImageGallery(images: message.images),
          ],
        ),
      );
    }
    return ListTile(
      leading: const Icon(Icons.chat_bubble_outline, size: 20),
      title: Text(
        message.body.isEmpty
            ? (message.referenceKind != null
                  ? 'Shared ${message.referenceKind}'
                  : 'Photo attachment')
            : message.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${message.sender?.displayName ?? 'Member'} · ${DateFormat.MMMd().format(message.at)}',
      ),
      onTap: onJump,
    );
  }
}
