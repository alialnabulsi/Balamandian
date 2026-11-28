import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/guide/widgets/guide_markdown_body.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Iterable<TextSpan> spans(InlineSpan span) sync* {
  if (span is TextSpan) {
    yield span;
    for (final child in span.children ?? <InlineSpan>[]) {
      yield* spans(child);
    }
  }
}

void main() {
  testWidgets(
    'native Markdown renders headings, lists, emphasis, links, code and tables',
    (tester) async {
      final links = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuideMarkdownBody(
                markdown: '# Heading\n\nA **strong** and *emphasized* paragraph.\n\n- First item\n- Second item\n\n> A quotation\n\n`inline code`\n\n```\ncode block\n```\n\n| Column | Value |\n| --- | --- |\n| One | Two |\n\n[Official source](https://www.balamand.edu.lb/)',
                onLink: links.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((t) => t.data ?? t.textSpan!.toPlainText())
          .join(' ');
      for (final expected in [
        'Heading',
        'strong',
        'emphasized',
        'First item',
        'Second item',
        'quotation',
        'inline code',
        'code block',
        'Column',
        'One',
        'Two',
        'Official source',
      ]) {
        expect(text, contains(expected));
      }
      final allSpans = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .expand(
            (t) => t.textSpan == null ? <TextSpan>[] : spans(t.textSpan!),
          );
      expect(
        allSpans.any(
          (s) => s.text == 'strong' && s.style?.fontWeight == FontWeight.bold,
        ),
        isTrue,
      );
      final link = allSpans.firstWhere(
        (s) => s.recognizer is TapGestureRecognizer,
      );
      (link.recognizer! as TapGestureRecognizer).onTap!();
      expect(links, ['https://www.balamand.edu.lb/']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'raw HTML blocks are not rendered and images never load embedded content',
    (tester) async {
      final links = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: GuideMarkdownBody(
              markdown: '<script>alert(1)</script>\n\n<iframe src="https://untrusted.invalid"></iframe>\n\n![Local image](file:///private/secret.png)\n\n![Remote image](https://untrusted.invalid/tracker.png)',
              onLink: links.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(links, isEmpty);
      expect(find.byType(GuideMarkdownImageLink), findsNWidgets(2));
      final text = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((t) => t.data ?? t.textSpan!.toPlainText())
          .join(' ');
      expect(text, isNot(contains('alert(1)')));
      expect(text, isNot(contains('<iframe')));
      expect(tester.takeException(), isNull);
    },
  );
}
