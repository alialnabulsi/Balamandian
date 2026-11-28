import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/ai_conversation.dart';
import 'ai_markdown_document.dart';
import 'ai_text_direction.dart';

class AiMarkdown extends StatefulWidget {
  const AiMarkdown({
    super.key,
    required this.body,
    this.provisional = false,
    this.citationCount = 0,
    this.onCitation,
    this.onLink,
  });

  final String body;
  final bool provisional;
  final int citationCount;
  final ValueChanged<int>? onCitation;
  final ValueChanged<Uri>? onLink;

  @override
  State<AiMarkdown> createState() => _AiMarkdownState();
}

class _AiMarkdownState extends State<AiMarkdown> {
  late List<AiMarkdownBlock> _blocks = _parse();

  List<AiMarkdownBlock> _parse() =>
      parseAiMarkdown(widget.body, provisional: widget.provisional);

  @override
  void didUpdateWidget(covariant AiMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body ||
        oldWidget.provisional != widget.provisional) {
      _blocks = _parse();
    }
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: _MarkdownBlocks(
      blocks: _blocks,
      settings: widget,
      fallback: aiTextDirection(widget.body),
    ),
  );
}

class _MarkdownBlocks extends StatelessWidget {
  const _MarkdownBlocks({
    required this.blocks,
    required this.settings,
    required this.fallback,
  });

  final List<AiMarkdownBlock> blocks;
  final AiMarkdown settings;
  final TextDirection fallback;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      for (final block in blocks)
        switch (block) {
          AiMarkdownText(:final text, :final heading) => _MarkdownLine(
            text,
            settings: settings,
            fallback: fallback,
            heading: heading,
          ),
          AiMarkdownList(:final items) => _MarkdownList(
            items,
            settings,
            fallback,
          ),
          AiMarkdownQuote(:final blocks) => _MarkdownQuote(
            blocks,
            settings,
            fallback,
          ),
          AiMarkdownCode(:final text, :final language) => _CodeBlock(
            text,
            language,
          ),
          AiMarkdownTable(:final rows) => _MarkdownTable(
            rows,
            settings,
            fallback,
          ),
          AiMarkdownRule() => const Divider(height: 1),
        },
    ],
  );
}

TextDirection _blockDirection(
  List<AiMarkdownBlock> blocks,
  TextDirection fallback,
) {
  for (final block in blocks) {
    switch (block) {
      case AiMarkdownText(:final text):
        return aiTextDirection(text, fallback);
      case AiMarkdownList(:final items) when items.isNotEmpty:
        return _blockDirection(items.first.blocks, fallback);
      case AiMarkdownQuote(:final blocks):
        return _blockDirection(blocks, fallback);
      case AiMarkdownTable(:final rows):
        return aiTextDirection(rows.first.join(' '), fallback);
      default:
        continue;
    }
  }
  return fallback;
}

class _MarkdownLine extends StatelessWidget {
  const _MarkdownLine(
    this.text, {
    required this.settings,
    required this.fallback,
    this.heading = 0,
    this.strong = false,
  });

  final String text;
  final AiMarkdown settings;
  final TextDirection fallback;
  final int heading;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = parseAiInline(text, provisional: settings.provisional);
    final readable = tokens
        .where((token) => token.kind != AiInlineKind.citation)
        .map((token) => token.text)
        .join(' ');
    final direction = aiTextDirection(readable, fallback);
    final typography = theme.textTheme;
    final style = switch (heading) {
      0 => typography.bodyLarge,
      1 => typography.headlineSmall,
      2 => typography.titleLarge,
      _ => typography.titleMedium,
    };
    final content = Text.rich(
      TextSpan(
        children: [
          for (final token in tokens) _span(context, token, direction),
        ],
      ),
      textDirection: direction,
      textAlign: TextAlign.start,
      style: style?.copyWith(
        height: direction == TextDirection.rtl ? 1.75 : 1.55,
        fontWeight: heading > 0 || strong ? FontWeight.w700 : null,
      ),
    );
    return heading == 0 ? content : Semantics(header: true, child: content);
  }

  InlineSpan _span(
    BuildContext context,
    AiInline token,
    TextDirection direction,
  ) {
    final colors = Theme.of(context).colorScheme;
    switch (token.kind) {
      case AiInlineKind.text:
        return TextSpan(text: token.text);
      case AiInlineKind.bold:
      case AiInlineKind.italic:
      case AiInlineKind.boldItalic:
        return TextSpan(
          children: [
            for (final child in parseAiInline(
              token.text,
              provisional: settings.provisional,
            ))
              _span(context, child, direction),
          ],
          style: TextStyle(
            fontWeight: token.kind == AiInlineKind.italic
                ? null
                : FontWeight.w700,
            fontStyle: token.kind == AiInlineKind.bold
                ? null
                : FontStyle.italic,
          ),
        );
      case AiInlineKind.identifier:
        return TextSpan(text: '\u2066${token.text}\u2069');
      case AiInlineKind.code:
        return TextSpan(
          text: '\u2068${token.text}\u2069',
          style: TextStyle(
            fontFamily: 'monospace',
            color: colors.primary,
            backgroundColor: colors.surfaceContainer,
          ),
        );
      case AiInlineKind.link:
        final url = safeAiUrl(token.target!);
        final open = settings.onLink;
        if (url == null || open == null || settings.provisional) {
          return TextSpan(text: token.text);
        }
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineAction(
            label: token.text,
            tooltip: url.host,
            onTap: () => open(url),
            direction: aiTextDirection(token.text, direction),
          ),
        );
      case AiInlineKind.citation:
        final index = int.tryParse(token.target!);
        final open = settings.onCitation;
        if (index == null || index > settings.citationCount || open == null) {
          return TextSpan(text: settings.provisional ? '' : token.text);
        }
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineAction(
            label: '$index',
            tooltip: 'Source $index',
            onTap: () => open(index - 1),
            direction: TextDirection.ltr,
            citation: true,
          ),
        );
    }
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.label,
    required this.tooltip,
    required this.onTap,
    required this.direction,
    this.citation = false,
  });

  final String label, tooltip;
  final VoidCallback onTap;
  final TextDirection direction;
  final bool citation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        link: true,
        label: citation ? tooltip : null,
        child: Material(
          color: citation ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: citation
                  ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1)
                  : EdgeInsets.zero,
              child: ExcludeSemantics(
                excluding: citation,
                child: Text(
                  label,
                  textDirection: direction,
                  style: citation
                      ? theme.textTheme.labelSmall?.copyWith(
                          color: colors.onPrimaryContainer,
                        )
                      : theme.textTheme.bodyMedium?.copyWith(
                          color: colors.primary,
                          decoration: TextDecoration.underline,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkdownList extends StatelessWidget {
  const _MarkdownList(this.items, this.settings, this.fallback);

  final List<AiMarkdownListItem> items;
  final AiMarkdown settings;
  final TextDirection fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      spacing: 6,
      children: [
        for (final item in items)
          Directionality(
            textDirection: _blockDirection(item.blocks, fallback),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    item.marker,
                    textDirection: Directionality.of(context),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.65,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: _MarkdownBlocks(
                      blocks: item.blocks,
                      settings: settings,
                      fallback: fallback,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MarkdownQuote extends StatelessWidget {
  const _MarkdownQuote(this.blocks, this.settings, this.fallback);

  final List<AiMarkdownBlock> blocks;
  final AiMarkdown settings;
  final TextDirection fallback;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final direction = _blockDirection(blocks, fallback);
    return Directionality(
      textDirection: direction,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 10, 6),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(width: 3, color: colors.outline),
          ),
        ),
        child: _MarkdownBlocks(
          blocks: blocks,
          settings: settings,
          fallback: direction,
        ),
      ),
    );
  }
}

class _MarkdownTable extends StatefulWidget {
  const _MarkdownTable(this.rows, this.settings, this.fallback);

  final List<List<String>> rows;
  final AiMarkdown settings;
  final TextDirection fallback;

  @override
  State<_MarkdownTable> createState() => _MarkdownTableState();
}

class _MarkdownTableState extends State<_MarkdownTable> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = widget.rows;
    final direction = aiTextDirection(rows.first.join(' '), widget.fallback);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimum = MediaQuery.textScalerOf(context).scale(112);
        final columnWidth = (constraints.maxWidth / rows.first.length).clamp(
          minimum,
          minimum > 260 ? minimum : 260.0,
        );
        return Directionality(
          textDirection: direction,
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility:
                columnWidth * rows.first.length > constraints.maxWidth,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              primary: false,
              child: Table(
                border: TableBorder.all(color: colors.outlineVariant),
                defaultColumnWidth: FixedColumnWidth(columnWidth),
                children: [
                  for (final (index, row) in rows.indexed)
                    TableRow(
                      decoration: index == 0
                          ? BoxDecoration(color: colors.surfaceContainerLow)
                          : null,
                      children: [
                        for (final cell in row)
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: _MarkdownLine(
                              cell,
                              settings: widget.settings,
                              fallback: direction,
                              strong: index == 0,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.text, this.language);

  final String text, language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.isEmpty ? 'Code' : language,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy code',
                  onPressed: () => copyAiText(context, text, 'Code copied'),
                  icon: const Icon(Icons.content_copy_rounded, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              padding: const EdgeInsets.all(12),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> copyAiText(
  BuildContext context,
  String text,
  String confirmation,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(confirmation)));
  }
}
