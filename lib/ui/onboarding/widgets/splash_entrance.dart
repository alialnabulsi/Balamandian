import 'package:flutter/widgets.dart';

/// Subtle entrance motion driven by the splash's visibility-gated timeline.
class SplashEntrance extends StatelessWidget {
  const SplashEntrance({
    super.key,
    required this.progress,
    required this.child,
    this.offset = 14,
  });
  final Animation<double> progress;
  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    child: child,
    builder: (context, child) => Opacity(
      opacity: progress.value,
      child: Transform.translate(
        offset: Offset(0, offset * (1 - progress.value)),
        child: child,
      ),
    ),
  );
}
