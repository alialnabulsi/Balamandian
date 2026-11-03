import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/crest_coin.dart';

class SplashLoadingLogo extends StatelessWidget {
  const SplashLoadingLogo({super.key, required this.progress});
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: 156,
      child: CustomPaint(
        foregroundPainter: _LoadingStroke(progress),
        child: const Padding(padding: EdgeInsets.all(12), child: CrestCoin()),
      ),
    ),
  );
}

class _LoadingStroke extends CustomPainter {
  _LoadingStroke(this.progress) : super(repaint: progress);
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress.value == 0) return;
    canvas.drawArc(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: size.width / 2 - 2,
      ),
      -math.pi / 2,
      math.pi * 2 * progress.value,
      false,
      Paint()
        ..color = StartupTokens.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LoadingStroke oldDelegate) =>
      progress != oldDelegate.progress;
}
