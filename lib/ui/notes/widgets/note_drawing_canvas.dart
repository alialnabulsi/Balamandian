import 'package:flutter/material.dart';

import '../../../domain/models/note_models.dart';

const noteInkColors = [
  Color(0xff182b3a),
  Color(0xff12579d),
  Color(0xffa12b46),
  Color(0xff2b7558),
  Color(0xffa97016),
];

class NoteDrawingCanvas extends StatelessWidget {
  const NoteDrawingCanvas({
    super.key,
    required this.strokes,
    this.onStart,
    this.onPoint,
    this.onEnd,
    this.onCancel,
  });
  final List<InkStroke> strokes;
  final ValueChanged<InkPoint>? onStart, onPoint;
  final VoidCallback? onEnd, onCancel;
  @override
  Widget build(BuildContext context) => Semantics(
    label: onStart == null ? 'Handwritten drawing' : 'Drawing canvas. Draw with a finger or stylus. Toolbar provides eraser and undo.',
    image: onStart == null,
    child: AspectRatio(
      aspectRatio: 4 / 3,
      child: LayoutBuilder(
        builder: (context, size) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: onStart == null
              ? null
              : (d) => onStart!(
                  InkPoint(
                    (d.localPosition.dx / size.maxWidth).clamp(0, 1),
                    (d.localPosition.dy / size.maxHeight).clamp(0, 1),
                  ),
                ),
          onPanUpdate: onPoint == null
              ? null
              : (d) => onPoint!(
                  InkPoint(
                    (d.localPosition.dx / size.maxWidth).clamp(0, 1),
                    (d.localPosition.dy / size.maxHeight).clamp(0, 1),
                  ),
                ),
          onPanEnd: onEnd == null ? null : (_) => onEnd!(),
          onPanCancel: onCancel,
          child: CustomPaint(
            painter: NoteInkPainter(strokes),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

class NoteInkPainter extends CustomPainter {
  const NoteInkPainter(this.strokes);
  final List<InkStroke> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    for (final s in strokes) {
      final paint = Paint()
        ..color = noteInkColors[s.color]
        ..strokeWidth = s.width * size.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        final p = s.points.first;
        canvas.drawCircle(
          Offset(p.x * size.width, p.y * size.height),
          s.width * size.width / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        final path = Path();
        for (final (i, p) in s.points.indexed) {
          if (i == 0) {
            path.moveTo(p.x * size.width, p.y * size.height);
          } else {
            path.lineTo(p.x * size.width, p.y * size.height);
          }
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(NoteInkPainter oldDelegate) =>
      oldDelegate.strokes != strokes;
}
