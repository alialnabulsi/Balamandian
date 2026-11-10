import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A static vector tile, isolated from foreground scrolling and interaction.
class AppBrandedBackground extends StatelessWidget {
  const AppBrandedBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Color.alphaBlend(
        scheme.primary.withValues(alpha: .025),
        scheme.surface,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _AcademicPattern(
                      scheme.primary.withValues(
                        alpha: scheme.brightness == Brightness.dark
                            ? .07
                            : .055,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AcademicPattern extends CustomPainter {
  const _AcademicPattern(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var y = -32.0; y < size.height + 200; y += 200) {
      for (var x = -24.0; x < size.width + 200; x += 200) {
        canvas.save();
        canvas.translate(x, y);
        _branch(canvas, paint, const Offset(24, 35), -.6);
        _cap(canvas, paint, const Offset(118, 24), .2);
        _book(canvas, paint, const Offset(40, 124), -.15);
        _branch(canvas, paint, const Offset(133, 132), .8);
        _spark(canvas, paint, const Offset(95, 95));
        _spark(canvas, paint, const Offset(184, 180));
        canvas.restore();
      }
    }
  }

  void _branch(Canvas canvas, Paint paint, Offset at, double rotation) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(rotation);
    canvas.drawPath(
      Path()
        ..moveTo(0, 42)
        ..quadraticBezierTo(20, 25, 12, 0),
      paint,
    );
    for (var i = 0; i < 4; i++) {
      final y = 8.0 + i * 8;
      canvas.drawPath(
        Path()
          ..moveTo(14, y)
          ..quadraticBezierTo(26, y - 10, 27, y - 17)
          ..quadraticBezierTo(15, y - 14, 14, y),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(14, y + 3)
          ..quadraticBezierTo(1, y + 1, -2, y - 7)
          ..quadraticBezierTo(10, y - 8, 14, y + 3),
        paint,
      );
    }
    canvas.restore();
  }

  void _cap(Canvas canvas, Paint paint, Offset at, double rotation) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(rotation);
    canvas.drawPath(
      Path()
        ..moveTo(0, 12)
        ..lineTo(23, 0)
        ..lineTo(46, 12)
        ..lineTo(23, 24)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(10, 18)
        ..lineTo(10, 29)
        ..quadraticBezierTo(23, 39, 36, 29)
        ..lineTo(36, 18),
      paint,
    );
    canvas.drawLine(const Offset(46, 12), const Offset(46, 32), paint);
    canvas.restore();
  }

  void _book(Canvas canvas, Paint paint, Offset at, double rotation) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(rotation);
    canvas.drawPath(
      Path()
        ..moveTo(23, 5)
        ..quadraticBezierTo(12, -1, 0, 2)
        ..lineTo(0, 33)
        ..quadraticBezierTo(12, 30, 23, 36)
        ..quadraticBezierTo(34, 30, 46, 33)
        ..lineTo(46, 2)
        ..quadraticBezierTo(34, -1, 23, 5)
        ..lineTo(23, 36),
      paint,
    );
    for (var y = 11.0; y <= 25; y += 7) {
      canvas.drawLine(Offset(6, y), Offset(17, y + 2), paint);
      canvas.drawLine(Offset(29, y + 2), Offset(40, y), paint);
    }
    canvas.restore();
  }

  void _spark(Canvas canvas, Paint paint, Offset at) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(math.pi / 8);
    canvas.drawPath(
      Path()
        ..moveTo(0, -7)
        ..quadraticBezierTo(1, -1, 7, 0)
        ..quadraticBezierTo(1, 1, 0, 7)
        ..quadraticBezierTo(-1, 1, -7, 0)
        ..quadraticBezierTo(-1, -1, 0, -7),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AcademicPattern oldDelegate) =>
      color != oldDelegate.color;
}
