import 'package:flutter/material.dart';

import '../../../domain/models/note_models.dart';

class NoteTextBlock extends StatefulWidget {
  const NoteTextBlock({
    super.key,
    required this.block,
    required this.onChanged,
    required this.onSelect,
    required this.onRemove,
    this.number = 0,
    this.blankPage = false,
  });
  final NoteBlock block;
  final ValueChanged<String> onChanged;
  final VoidCallback onSelect, onRemove;
  final int number;
  final bool blankPage;
  @override
  State<NoteTextBlock> createState() => _NoteTextBlockState();
}

class _NoteTextBlockState extends State<NoteTextBlock> {
  late final _text = TextEditingController(text: widget.block.text);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block, theme = Theme.of(context);
    final base = b.type == 'heading'
        ? theme.textTheme.titleLarge
        : theme.textTheme.bodyLarge;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (b.type == 'bullet' || b.type == 'numbered')
          Padding(
            padding: const EdgeInsets.only(top: 16, right: 8),
            child: Text(
              b.type == 'bullet' ? '•' : '${widget.number}.',
              style: base,
            ),
          ),
        Expanded(
          child: TextField(
            controller: _text,
            autofocus: widget.blankPage && b.text.isEmpty,
            minLines: widget.blankPage ? 10 : 1,
            maxLines: null,
            style: base?.copyWith(
              fontWeight: b.bold ? FontWeight.bold : base.fontWeight,
              fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
              decoration: b.underline
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
            onTap: widget.onSelect,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: b.type == 'heading' ? 'Heading' : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              labelText: b.type == 'heading' ? 'Heading' : null,
            ),
          ),
        ),
        if (!widget.blankPage)
          IconButton(
            tooltip: 'Remove paragraph',
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
      ],
    );
  }
}
