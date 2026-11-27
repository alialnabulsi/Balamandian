import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/models/note_models.dart';
import '../view_models/drawing_view_model.dart';
import 'note_drawing_canvas.dart';

class NoteDrawingEditor extends StatefulWidget {
  const NoteDrawingEditor({super.key, required this.strokes, this.onChanged});
  final List<InkStroke> strokes;
  final ValueChanged<List<InkStroke>>? onChanged;
  @override
  State<NoteDrawingEditor> createState() => _NoteDrawingEditorState();
}

class _NoteDrawingEditorState extends State<NoteDrawingEditor> {
  late final _model = DrawingViewModel(widget.strokes);
  Timer? _stage;
  @override
  void initState() {
    super.initState();
    _model.addListener(_changed);
  }

  void _changed() {
    if (_stage?.isActive != true) {
      _stage = Timer(const Duration(milliseconds: 120), _stageNow);
    }
  }

  void _stageNow() {
    _stage?.cancel();
    widget.onChanged?.call([
      ..._model.strokes,
      if (_model.active.isNotEmpty)
        InkStroke(
          color: _model.color,
          width: _model.width,
          points: List.of(_model.active),
        ),
    ]);
  }

  @override
  void dispose() {
    _stage?.cancel();
    _model.removeListener(_changed);
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Drawing'),
        leading: IconButton(
          tooltip: 'Cancel drawing changes',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Insert drawing',
            onPressed: () {
              _model.end();
              _stageNow();
              Navigator.pop(context, _model.strokes);
            },
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < noteInkColors.length; i++)
                    IconButton(
                      tooltip: 'Pen colour ${i + 1}',
                      isSelected: _model.color == i && !_model.eraser,
                      onPressed: () => _model.pen(color: i, erase: false),
                      icon: Icon(Icons.circle, color: noteInkColors[i]),
                    ),
                  PopupMenuButton<double>(
                    tooltip: 'Pen width',
                    onSelected: (v) => _model.pen(width: v, erase: false),
                    itemBuilder: (_) => [
                      for (final (v, label) in [
                        (.004, 'Fine'),
                        (.008, 'Medium'),
                        (.016, 'Thick'),
                      ])
                        PopupMenuItem(value: v, child: Text(label)),
                    ],
                    icon: const Icon(Icons.line_weight_rounded),
                  ),
                  IconButton(
                    tooltip: 'Eraser (whole stroke)',
                    isSelected: _model.eraser,
                    onPressed: () => _model.pen(erase: !_model.eraser),
                    icon: const Icon(Icons.auto_fix_normal_rounded),
                  ),
                  IconButton(
                    tooltip: 'Undo stroke',
                    onPressed: _model.canUndo ? _model.undo : null,
                    icon: const Icon(Icons.undo_rounded),
                  ),
                  IconButton(
                    tooltip: 'Redo stroke',
                    onPressed: _model.canRedo ? _model.redo : null,
                    icon: const Icon(Icons.redo_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: NoteDrawingCanvas(
                  strokes: [
                    ..._model.strokes,
                    if (_model.active.isNotEmpty)
                      InkStroke(
                        color: _model.color,
                        width: _model.width,
                        points: _model.active,
                      ),
                  ],
                  onStart: _model.start,
                  onPoint: _model.point,
                  onEnd: () {
                    _model.end();
                    _stageNow();
                  },
                  onCancel: () {
                    _model.cancel();
                    _stageNow();
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Draw inside the paper. Eraser removes whole strokes. Checkmark keeps editable ink.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
