import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Native Markdown widgets only: HTML blocks are not rendered; inline HTML is inert.
/// Images never fetch files/network content; a link can open through the same URL guard.
class GuideMarkdownBody extends StatelessWidget {
  const GuideMarkdownBody({
    super.key,
    required this.markdown,
    required this.onLink,
  });
  final String markdown;
  final ValueChanged<String?> onLink;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: markdown,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge,
        h1: theme.textTheme.headlineMedium,
        h2: theme.textTheme.headlineSmall,
        h3: theme.textTheme.titleLarge,
        blockSpacing: 16,
      ),
      onTapLink: (_, href, _) => onLink(href),
      imageBuilder: (uri, title, alt) => GuideMarkdownImageLink(
        label: alt ?? title ?? 'Article image',
        url: uri.toString(),
        onLink: onLink,
      ),
      // No raw HTML builders, WebView or embedded-content handlers are registered.
    );
  }
}

class GuideMarkdownImageLink extends StatelessWidget {
  const GuideMarkdownImageLink({
    super.key,
    required this.label,
    required this.url,
    required this.onLink,
  });
  final String label, url;
  final ValueChanged<String?> onLink;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => onLink(url),
    icon: const Icon(Icons.image_outlined),
    label: Text(label),
  );
}
