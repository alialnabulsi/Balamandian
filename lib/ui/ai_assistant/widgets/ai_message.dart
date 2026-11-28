import 'package:flutter/material.dart';

import '../../../domain/models/ai_conversation.dart';
import '../view_models/ai_assistant_view_model.dart';
import 'ai_markdown.dart';
import 'ai_sources.dart';
import 'ai_text_direction.dart';

class AiQuestion extends StatelessWidget {
  const AiQuestion(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final direction = aiTextDirection(text);
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * .87),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: SelectableText(
                text,
                textDirection: direction,
                textAlign: TextAlign.start,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                semanticsLabel: 'You: $text',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AiAnswer extends StatelessWidget {
  const AiAnswer({
    super.key,
    required this.answer,
    required this.onCitation,
    required this.onLink,
    required this.onFeedback,
    this.onRegenerate,
    this.vote,
    this.savingVote = false,
  });

  final AiAttempt answer;
  final ValueChanged<AiCitation> onCitation;
  final ValueChanged<Uri> onLink;
  final ValueChanged<int> onFeedback;
  final VoidCallback? onRegenerate;
  final int? vote;
  final bool savingVote;

  @override
  Widget build(BuildContext context) {
    final citations = answer.citations;
    final body = answer.body ?? '';
    void open(int index) => onCitation(citations[index]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiMarkdown(
          body: body,
          citationCount: citations.length,
          onCitation: open,
          onLink: onLink,
        ),
        if (citations.isNotEmpty) AiSources(citations: citations, onOpen: open),
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            children: [
              IconButton(
                tooltip: 'Copy answer',
                onPressed: () => copyAiText(context, body, 'Answer copied'),
                icon: const Icon(Icons.content_copy_rounded, size: 19),
              ),
              IconButton(
                tooltip: 'Good answer',
                isSelected: vote == 1,
                onPressed: savingVote ? null : () => onFeedback(1),
                icon: const Icon(Icons.thumb_up_outlined, size: 19),
                selectedIcon: const Icon(Icons.thumb_up_rounded, size: 19),
              ),
              IconButton(
                tooltip: 'Poor answer',
                isSelected: vote == -1,
                onPressed: savingVote ? null : () => onFeedback(-1),
                icon: const Icon(Icons.thumb_down_outlined, size: 19),
                selectedIcon: const Icon(Icons.thumb_down_rounded, size: 19),
              ),
              if (onRegenerate != null)
                IconButton(
                  tooltip: 'Regenerate answer',
                  onPressed: onRegenerate,
                  icon: const Icon(Icons.refresh_rounded, size: 21),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class AiPendingAnswer extends StatelessWidget {
  const AiPendingAnswer({
    super.key,
    required this.run,
    required this.onRecover,
    required this.onStop,
    required this.onRetryDelivery,
  });

  final AiRun run;
  final VoidCallback onRecover, onStop, onRetryDelivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = run.stopping && run.checking
        ? 'Stopping generation…'
        : run.connected
        ? (run.provisional.isEmpty
              ? 'Preparing your answer…'
              : 'Writing answer…')
        : run.checking
        ? 'Checking the saved answer…'
        : run.stopping
        ? 'Couldn’t confirm that generation stopped.'
        : 'The connection ended before the answer was confirmed.';
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (run.connected && run.provisional.isNotEmpty)
          AiMarkdown(body: run.provisional, provisional: true),
        Semantics(
          liveRegion: true,
          child: Row(
            spacing: 8,
            children: [
              if ((run.connected || run.checking) && !reduced)
                const SizedBox.square(
                  dimension: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  run.connected || run.checking
                      ? Icons.more_horiz_rounded
                      : Icons.cloud_off_outlined,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              Expanded(
                child: Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!run.connected && !run.checking)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: onRecover,
                  child: const Text('Check saved answer'),
                ),
                if (run.canRetryDelivery)
                  TextButton(
                    onPressed: onRetryDelivery,
                    child: const Text('Retry delivery'),
                  ),
                if (!run.stopping)
                  TextButton(
                    onPressed: onStop,
                    child: const Text('Stop generation'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
