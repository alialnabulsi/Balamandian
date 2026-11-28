sealed class AiMarkdownBlock {
  const AiMarkdownBlock();
}

class AiMarkdownText extends AiMarkdownBlock {
  const AiMarkdownText(this.text, {this.heading = 0});
  final String text;
  final int heading;
}

class AiMarkdownQuote extends AiMarkdownBlock {
  const AiMarkdownQuote(this.blocks);
  final List<AiMarkdownBlock> blocks;
}

class AiMarkdownRule extends AiMarkdownBlock {
  const AiMarkdownRule();
}

class AiMarkdownCode extends AiMarkdownBlock {
  const AiMarkdownCode(this.language, this.text);
  final String language, text;
}

class AiMarkdownTable extends AiMarkdownBlock {
  const AiMarkdownTable(this.rows);
  final List<List<String>> rows;
}

class AiMarkdownList extends AiMarkdownBlock {
  const AiMarkdownList(this.items);
  final List<AiMarkdownListItem> items;
}

class AiMarkdownListItem {
  const AiMarkdownListItem(this.marker, this.blocks);
  final String marker;
  final List<AiMarkdownBlock> blocks;
}

final _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})\s*([^\s`~]*)');
final _heading = RegExp(r'^ {0,3}(#{1,6})(?:\s+|$)(.*)$');
final _setext = RegExp(r'^ {0,3}(=+|-+)\s*$');
final _rule = RegExp(r'^ {0,3}(?:(?:\*\s*){3,}|(?:-\s*){3,}|(?:_\s*){3,})$');
final _bullet = RegExp(r'^( *)([-+*]|[0-9٠-٩۰-۹]{1,9}[.)])[ \t]+(.*)$');
final _quote = RegExp(r'^ {0,3}> ?');
final _tableDivider = RegExp(r'^:?-{3,}:?$');
final _pipe = RegExp(r'(?<!\\)\|');

List<AiMarkdownBlock> parseAiMarkdown(
  String markdown, {
  bool provisional = false,
}) {
  var text = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (provisional) {
    text = text
        .replaceAll(RegExp(r'\[\[(?:E[0-9]+|INSUFFICIENT)\]\]'), '')
        .replaceFirst(RegExp(r'\[\[(?:E\d*|[A-Z]*)?\]?\s*$|\[\d*\s*$'), '');
  }
  return _parse(text.split('\n'), provisional, 0);
}

List<AiMarkdownBlock> _parse(List<String> lines, bool provisional, int depth) {
  // Deeply nested generated content is still readable as text.
  if (depth == 12) return [AiMarkdownText(lines.join('\n'))];
  final blocks = <AiMarkdownBlock>[];
  var i = 0;
  bool tableAt(int line) =>
      line + 1 < lines.length &&
      lines[line].contains(_pipe) &&
      _cells(lines[line]).length == _cells(lines[line + 1]).length &&
      _cells(lines[line + 1]).every(_tableDivider.hasMatch);
  bool boundary(int line) {
    final text = lines[line];
    return text.trim().isEmpty ||
        _fence.hasMatch(text) ||
        _heading.hasMatch(text) ||
        _rule.hasMatch(text) ||
        _quote.hasMatch(text) ||
        _bullet.hasMatch(text) ||
        tableAt(line);
  }

  while (i < lines.length) {
    final line = lines[i];
    if (line.trim().isEmpty) {
      i++;
      continue;
    }
    final fence = _fence.firstMatch(line);
    if (fence != null) {
      final marker = fence[1]!;
      final closing = RegExp('^ {0,3}${marker[0]}{${marker.length},}\\s*\$');
      final body = <String>[];
      i++;
      while (i < lines.length && !closing.hasMatch(lines[i])) {
        body.add(lines[i++]);
      }
      if (i < lines.length) i++;
      if (body.isNotEmpty || !provisional) {
        blocks.add(AiMarkdownCode(fence[2]!, body.join('\n')));
      }
      continue;
    }
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      final content = heading[2]!.replaceFirst(RegExp(r'\s+#+\s*$'), '');
      if (content.isNotEmpty) {
        blocks.add(AiMarkdownText(content, heading: heading[1]!.length));
      }
      i++;
      continue;
    }
    if (_rule.hasMatch(line)) {
      blocks.add(const AiMarkdownRule());
      i++;
      continue;
    }
    if (_quote.hasMatch(line)) {
      final quoted = <String>[];
      while (i < lines.length && _quote.hasMatch(lines[i])) {
        quoted.add(lines[i++].replaceFirst(_quote, ''));
      }
      blocks.add(AiMarkdownQuote(_parse(quoted, provisional, depth + 1)));
      continue;
    }
    if (tableAt(i)) {
      final rows = [_cells(line)];
      final columns = rows.first.length;
      i += 2;
      while (i < lines.length &&
          lines[i].contains(_pipe) &&
          _cells(lines[i]).length == columns) {
        rows.add(_cells(lines[i++]));
      }
      blocks.add(AiMarkdownTable(rows));
      continue;
    }
    if (i + 1 < lines.length && _setext.hasMatch(lines[i + 1])) {
      blocks.add(
        AiMarkdownText(
          line,
          heading: lines[i + 1].trimLeft().startsWith('=') ? 1 : 2,
        ),
      );
      i += 2;
      continue;
    }
    final first = _bullet.firstMatch(line);
    if (first != null) {
      final indent = first[1]!.length;
      final ordered = first[2]!.length > 1;
      final items = <AiMarkdownListItem>[];
      while (i < lines.length) {
        final match = _bullet.firstMatch(lines[i]);
        if (match == null ||
            match[1]!.length != indent ||
            (match[2]!.length > 1) != ordered) {
          break;
        }
        final lead = match.start + match[0]!.length - match[3]!.length;
        final body = [match[3]!];
        i++;
        while (i < lines.length) {
          final next = lines[i];
          if (next.trim().isEmpty) {
            if (i + 1 >= lines.length ||
                lines[i + 1].length - lines[i + 1].trimLeft().length <=
                    indent) {
              break;
            }
            body.add('');
          } else {
            final spaces = next.length - next.trimLeft().length;
            if (spaces <= indent) break;
            body.add(next.substring(spaces < lead ? spaces : lead));
          }
          i++;
        }
        items.add(
          AiMarkdownListItem(
            ordered ? match[2]! : '•',
            _parse(body, provisional, depth + 1),
          ),
        );
        while (i < lines.length && lines[i].trim().isEmpty) {
          i++;
        }
      }
      blocks.add(AiMarkdownList(items));
      continue;
    }
    final paragraph = StringBuffer(line.trim());
    i++;
    while (i < lines.length && !boundary(i)) {
      final previous = lines[i - 1];
      final hardBreak = previous.endsWith('  ');
      paragraph
        ..write(hardBreak ? '\n' : ' ')
        ..write(lines[i++].trim());
    }
    blocks.add(AiMarkdownText(paragraph.toString()));
  }
  return blocks;
}

List<String> _cells(String text) {
  final value = text
      .trim()
      .replaceFirst(RegExp(r'^\|'), '')
      .replaceFirst(RegExp(r'(?<!\\)\|$'), '');
  return value.split(_pipe).map((cell) => cell.trim()).toList();
}

enum AiInlineKind {
  text,
  bold,
  italic,
  boldItalic,
  code,
  link,
  citation,
  identifier,
}

class AiInline {
  const AiInline(this.kind, this.text, [this.target]);
  final AiInlineKind kind;
  final String text;
  final String? target;
}

final _inline = RegExp(
  r'(\\[\\`*_\[\]<>!|])'
  r'|(`+)([^\n]+?)\2(?!`)'
  r'|!?\[([^\]\n]+)\]\(([^\s)]+)\)'
  r'|\[([1-9][0-9]*)\]'
  r'|(\*\*\*|___|\*\*|__|\*|(?<![\w])_)(?=\S)([^\n]+?)(?<=\S)\7(?!\*)'
  r'|(https?://[^\s<>()]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
  r'|[A-Za-z]{2,}[ -]?\d{2,}[A-Za-z]?\b'
  r'|(?<![\p{L}\p{Nd}])\p{Nd}+(?:(?:[.,/:-]\p{Nd}+)+(?:[%٪])?|[%٪]))',
  unicode: true,
);

List<AiInline> parseAiInline(String text, {bool provisional = false}) {
  if (provisional) {
    text = text.replaceFirst(RegExp(r'(?:\*{1,3}|_{1,3}|`{1,3})$'), '');
  }
  final result = <AiInline>[];
  var offset = 0;
  for (final match in _inline.allMatches(text)) {
    if (match.start > offset) {
      result.add(
        AiInline(AiInlineKind.text, text.substring(offset, match.start)),
      );
    }
    final token = match[0]!;
    final AiInline item;
    if (match[1] != null) {
      item = AiInline(AiInlineKind.text, token.substring(1));
    } else if (match[2] != null) {
      item = AiInline(AiInlineKind.code, match[3]!);
    } else if (match[4] != null) {
      item = token.startsWith('!')
          ? AiInline(AiInlineKind.text, match[4]!)
          : AiInline(AiInlineKind.link, match[4]!, match[5]);
    } else if (match[6] != null) {
      item = AiInline(AiInlineKind.citation, token, match[6]);
    } else if (match[7] != null) {
      final kind = switch (match[7]!.length) {
        1 => AiInlineKind.italic,
        2 => AiInlineKind.bold,
        _ => AiInlineKind.boldItalic,
      };
      item = AiInline(kind, match[8]!);
    } else {
      item = AiInline(AiInlineKind.identifier, token);
    }
    result.add(item);
    offset = match.end;
  }
  if (offset < text.length) {
    var tail = text.substring(offset);
    if (provisional) {
      // Keep the in-progress words visible while hiding unmatched delimiters.
      tail = tail.replaceAll(
        RegExp(r'(^|\s)(?:\*{1,3}|_{1,3}|`{1,3})(?=\S)'),
        r'$1',
      );
    }
    if (tail.isNotEmpty) result.add(AiInline(AiInlineKind.text, tail));
  }
  return result;
}
