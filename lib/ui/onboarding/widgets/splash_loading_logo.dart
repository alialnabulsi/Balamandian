import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';

class SplashLoadingLogo extends StatelessWidget {
  const SplashLoadingLogo({
    super.key,
    required this.progress,
    this.assetSize = 288,
  });
  // Android's generated logo has 600px of visible ink inside its 1152px asset.
  static const asset = 'assets/branding/splash_logo.png';
  static const inkFraction = 600 / 1152;
  final Animation<double> progress;
  final double assetSize;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: assetSize * inkFraction + 24,
      child: CustomPaint(
        foregroundPainter: _LoadingStroke(progress),
        child: OverflowBox(
          minWidth: assetSize,
          maxWidth: assetSize,
          minHeight: assetSize,
          maxHeight: assetSize,
          child: Image.asset(
            asset,
            width: assetSize,
            height: assetSize,
            fit: BoxFit.contain,
            semanticLabel: 'University of Balamand crest',
          ),
        ),
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
