import 'package:flutter/material.dart';

import '../../../domain/models/ai_conversation.dart';
import '../../../domain/models/guide_article_ref.dart';
import 'ai_text_direction.dart';

class AiSources extends StatelessWidget {
  const AiSources({super.key, required this.citations, required this.onOpen});

  final List<AiCitation> citations;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 20),
        Text('Sources', style: theme.textTheme.labelLarge),
        for (final (index, citation) in citations.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.surfaceContainer,
              child: Text('${index + 1}', style: theme.textTheme.labelSmall),
            ),
            title: Text(
              citation.article.title,
              textDirection: aiTextDirection(citation.article.title),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              [
                ?citation.heading,
                citation.source?.label ?? _availability(citation.availability),
              ].join(' · '),
              textDirection: aiTextDirection(
                citation.heading ?? citation.article.title,
              ),
            ),
            trailing: Icon(
              citation.availability == AiAvailability.unavailable
                  ? Icons.info_outline_rounded
                  : Icons.chevron_right_rounded,
              size: 20,
            ),
            onTap: () => onOpen(index),
          ),
      ],
    );
  }
}

class AiSourceDetails extends StatelessWidget {
  const AiSourceDetails({
    super.key,
    required this.citation,
    this.onGuide,
    required this.onExternal,
  });

  final AiCitation citation;
  final ValueChanged<GuideArticleRef>? onGuide;
  final ValueChanged<Uri> onExternal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = citation.source;
    final url = source?.url;
    final available = citation.availability != AiAvailability.unavailable;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Text(
              citation.article.title,
              textDirection: aiTextDirection(citation.article.title),
              style: theme.textTheme.headlineSmall,
            ),
            if (citation.heading case final heading?)
              Text(
                heading,
                textDirection: aiTextDirection(heading),
                style: theme.textTheme.bodyLarge,
              ),
            Text(
              '${_availability(citation.availability)} · Cited revision ${citation.article.version}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (source != null && available)
              Text(source.label, textDirection: aiTextDirection(source.label)),
            if (available && onGuide != null)
              FilledButton.icon(
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: () {
                  Navigator.of(context).pop();
                  onGuide!(citation.article);
                },
                label: const Text('Open in University Guide'),
              ),
            if (available && url != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () => onExternal(url),
                label: const Text('Open official source'),
              ),
          ],
        ),
      ),
    );
  }
}

String _availability(AiAvailability availability) => switch (availability) {
  AiAvailability.current => 'Current source',
  AiAvailability.updated => 'Article updated since this answer',
  AiAvailability.unavailable => 'Source unavailable',
};
