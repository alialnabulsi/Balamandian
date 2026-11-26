import 'package:flutter/material.dart';

import '../../../domain/models/community.dart';

class CommunityDiscussionHeader extends StatelessWidget {
  const CommunityDiscussionHeader({
    super.key,
    required this.reply,
    required this.onBack,
    required this.onResize,
  });

  final bool reply;
  final VoidCallback? onBack;
  final ValueChanged<bool> onResize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) =>
              onResize(details.primaryVelocity! < 0),
          onTap: () => onResize(true),
          excludeFromSemantics: true,
          child: SizedBox(
            width: double.infinity,
            height: 20,
            child: Center(
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (reply)
                IconButton(
                  tooltip: 'Back to all comments',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                )
              else
                const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    reply ? 'Replies' : 'Comments',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close comments',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 21),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class CommunityReplyContext extends StatelessWidget {
  const CommunityReplyContext({super.key, required this.comment});
  final CommunityComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Replying to ${comment.author.displayName}',
            style: theme.textTheme.labelLarge,
          ),
          Text(
            comment.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class CommunityCommentInput extends StatelessWidget {
  const CommunityCommentInput({
    super.key,
    required this.text,
    required this.focus,
    required this.isReply,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController text;
  final FocusNode focus;
  final bool isReply, sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 7, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: text,
                focusNode: focus,
                readOnly: sending,
                maxLength: 1000,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: isReply ? 'Write a reply' : 'Write a comment',
                  counterText: '',
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder(
              valueListenable: text,
              builder: (context, value, _) => IconButton.filled(
                tooltip: isReply ? 'Send reply' : 'Send comment',
                onPressed: sending || value.text.trim().isEmpty ? null : onSend,
                icon: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
