import 'package:flutter/material.dart';

import '../../../domain/models/note_models.dart';

class NoteFormattingToolbar extends StatelessWidget {
  const NoteFormattingToolbar({
    super.key,
    required this.selected,
    required this.onFormat,
    required this.onUndo,
    required this.onRedo,
    required this.onParagraph,
    required this.onDrawing,
    required this.onAttachment,
  });
  final NoteBlock? selected;
  final void Function({String? type, String? mark}) onFormat;
  final VoidCallback? onUndo, onRedo, onParagraph, onDrawing, onAttachment;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          PopupMenuButton<String>(
            tooltip: 'Paragraph style',
            enabled: selected != null,
            onSelected: (v) => onFormat(type: v),
            itemBuilder: (_) => [
              for (final entry in const {
                'paragraph': 'Paragraph',
                'heading': 'Heading',
                'bullet': 'Bullet list',
                'numbered': 'Numbered list',
              }.entries)
                PopupMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            icon: const Icon(Icons.text_fields_rounded),
          ),
          for (final (mark, icon, active) in [
            ('bold', Icons.format_bold_rounded, selected?.bold == true),
            ('italic', Icons.format_italic_rounded, selected?.italic == true),
            (
              'underline',
              Icons.format_underlined_rounded,
              selected?.underline == true,
            ),
          ])
            IconButton(
              tooltip: '${mark[0].toUpperCase()}${mark.substring(1)} paragraph',
              isSelected: active,
              onPressed: selected == null ? null : () => onFormat(mark: mark),
              icon: Icon(icon),
            ),
          IconButton(
            tooltip: 'Undo document edit',
            onPressed: onUndo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo document edit',
            onPressed: onRedo,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton(
            tooltip: 'Add paragraph',
            onPressed: onParagraph,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Insert drawing',
            onPressed: onDrawing,
            icon: const Icon(Icons.draw_outlined),
          ),
          IconButton(
            tooltip: 'Attach image or PDF',
            onPressed: onAttachment,
            icon: const Icon(Icons.attach_file_rounded),
          ),
        ],
      ),
    ),
  );
}
