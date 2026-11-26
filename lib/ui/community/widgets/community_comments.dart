import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';
import '../../core/ui/form_message.dart';
import '../view_models/community_comments_model.dart';
import 'community_actions.dart';
import 'community_author.dart';
import 'community_discussion.dart';
import 'community_post_card.dart';

class CommunityComments extends StatefulWidget {
  const CommunityComments({
    super.key,
    required this.repository,
    required this.post,
    required this.loadAvatar,
  });
  final CommunityRepository repository;
  final CommunityEntry post;
  final CommunityAvatarLoader loadAvatar;
  @override
  State<CommunityComments> createState() => _CommunityCommentsState();
}

class _CommunityCommentsState extends State<CommunityComments> {
  late final model = CommunityCommentsModel(widget.repository, widget.post);
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _sheet = DraggableScrollableController();
  final _drafts = <String?, String>{};
  bool _changed = false;
  @override
  void initState() {
    super.initState();
    unawaited(model.load(reset: true));
    widget.repository.addListener(_invalidate);
    _focus.addListener(_expandForKeyboard);
  }

  void _invalidate() {
    if (!mounted) return;
    _drafts[model.parent?.id] = _text.text;
    _text.text = _drafts[null] ?? '';
    unawaited(model.revalidate());
  }

  void _expandForKeyboard() {
    if (_focus.hasFocus) _resize(.96);
  }

  void _resize(double size) {
    if (!_sheet.isAttached) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _sheet.jumpTo(size);
    } else {
      unawaited(
        _sheet.animateTo(
          size,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  Future<void> _thread(CommunityComment? comment, {bool write = false}) async {
    if (model.sending) return;
    _drafts[model.parent?.id] = _text.text;
    _text.text = _drafts[comment?.id] ?? '';
    if (!write) _focus.unfocus();
    await model.thread(comment);
    if (mounted && write && model.canWrite) _focus.requestFocus();
  }

  @override
  void dispose() {
    widget.repository.removeListener(_invalidate);
    _text.dispose();
    _focus.dispose();
    _sheet.dispose();
    model.dispose();
    super.dispose();
  }

  Future<void> _options(CommunityComment comment) async {
    final action = await communityMenu<String>(
      context,
      child: CommunityMenuBody(
        title: 'Comment options',
        children: [
          if (comment.isOwn || widget.post.isOwn)
            const CommunityMenuOption(
              'Delete comment',
              Icons.delete_outline,
              'delete',
            ),
          if (!comment.isOwn)
            const CommunityMenuOption(
              'Report comment',
              Icons.flag_outlined,
              'report',
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'delete' &&
        await communityConfirm(
          context,
          'Delete comment?',
          'Any replies under this comment will also be removed.',
        )) {
      await model.remove(comment);
      if (mounted) _changed = true;
    }
    if (action == 'report' && mounted) {
      await communityMenu<void>(
        context,
        child: CommunityReportSheet(
          repository: widget.repository,
          kind: 'comment',
          id: comment.id,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop && _changed) {
        final repository = widget.repository;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (repository.userId != null) repository.invalidate();
        });
      }
    },
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        controller: _sheet,
        expand: false,
        initialChildSize: .56,
        minChildSize: .34,
        maxChildSize: .96,
        snap: true,
        snapSizes: const [.56],
        builder: (context, scroll) => ListenableBuilder(
          listenable: model,
          builder: (context, _) {
            final theme = Theme.of(context);
            return Material(
              color: theme.colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    CommunityDiscussionHeader(
                      reply: model.parent != null,
                      onBack: model.sending ? null : () => _thread(null),
                      onResize: (expand) => _resize(expand ? .96 : .56),
                    ),
                    if (model.loading)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Loading comments',
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount:
                            model.items.length + (model.parent == null ? 1 : 2),
                        itemBuilder: (context, index) {
                          final parent = model.parent;
                          if (parent != null && index == 0) {
                            return CommunityReplyContext(comment: parent);
                          }
                          final itemIndex = parent == null ? index : index - 1;
                          if (itemIndex == model.items.length) {
                            return Column(
                              children: [
                                if (!model.loading &&
                                    model.error == null &&
                                    model.items.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Text(
                                      model.parent == null
                                          ? 'Start the conversation'
                                          : 'No replies yet',
                                    ),
                                  ),
                                if (model.error != null)
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: FormMessage(model.error.toString()),
                                  ),
                                if (model.next != null || model.error != null)
                                  TextButton(
                                    onPressed: model.loading
                                        ? null
                                        : () => model.load(
                                            reset: model.items.isEmpty,
                                          ),
                                    child: Text(
                                      model.error != null
                                          ? 'Retry'
                                          : 'Load more',
                                    ),
                                  ),
                              ],
                            );
                          }
                          final comment = model.items[itemIndex];
                          return CommentRow(
                            comment: comment,
                            loadAvatar: widget.loadAvatar,
                            liked: model.liked(comment),
                            likePending: model.pending(comment),
                            onLike: () => model.toggle(comment),
                            onOptions: () => _options(comment),
                            onReply: model.parent == null
                                ? () => _thread(comment, write: true)
                                : null,
                            onOpenThread:
                                model.parent == null && comment.replies > 0
                                ? () => _thread(comment)
                                : null,
                          );
                        },
                      ),
                    ),
                    if (model.canWrite)
                      CommunityCommentInput(
                        text: _text,
                        focus: _focus,
                        isReply: model.parent != null,
                        sending: model.sending,
                        onSend: () async {
                          if (await model.send(_text.text) && mounted) {
                            _text.clear();
                            _drafts.remove(model.parent?.id);
                            _changed = true;
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class CommentRow extends StatelessWidget {
  const CommentRow({
    super.key,
    required this.comment,
    required this.loadAvatar,
    required this.liked,
    required this.likePending,
    required this.onLike,
    required this.onOptions,
    this.onReply,
    this.onOpenThread,
  });
  final CommunityComment comment;
  final CommunityAvatarLoader loadAvatar;
  final bool liked, likePending;
  final VoidCallback onLike, onOptions;
  final VoidCallback? onReply, onOpenThread;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = comment.createdAt?.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CommunityAuthor(
                  author: comment.author,
                  loadAvatar: loadAvatar,
                  size: 32,
                  subtitle: time == null
                      ? null
                      : DateFormat.MMMd().add_jm().format(time),
                ),
              ),
              CommunityPostAction(
                label: liked ? 'Unlike comment' : 'Like comment',
                onPressed: likePending ? null : onLike,
                icon: liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 18,
                color: liked ? theme.colorScheme.error : null,
                count:
                    (comment.likes + (liked ? 1 : 0) - (comment.liked ? 1 : 0))
                        .clamp(0, 1000000000),
              ),
              IconButton(
                tooltip: 'Comment options',
                onPressed: onOptions,
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 42, top: 2, right: 8),
            child: Text(comment.text, style: theme.textTheme.bodyMedium),
          ),
          if (onReply != null)
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Wrap(
                children: [
                  TextButton(onPressed: onReply, child: const Text('Reply')),
                  if (onOpenThread != null)
                    TextButton(
                      onPressed: onOpenThread,
                      child: Text(
                        comment.replies == 1
                            ? 'View reply'
                            : 'View ${comment.replies} replies',
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
