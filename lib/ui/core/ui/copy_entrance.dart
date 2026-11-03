import 'package:flutter/material.dart';

class CopyEntrance extends StatefulWidget {
  const CopyEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 450),
    this.delay = Duration.zero,
  });
  final Widget child;
  final Duration duration, delay;
  @override
  State<CopyEntrance> createState() => _CopyEntranceState();
}

class _CopyEntranceState extends State<CopyEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration + widget.delay,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion) {
      _controller.value = 1;
    } else if (_controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final elapsed =
          _controller.value * (widget.duration + widget.delay).inMicroseconds;
      final t = Curves.easeOut.transform(
        ((elapsed - widget.delay.inMicroseconds) /
                widget.duration.inMicroseconds)
            .clamp(0.0, 1.0),
      );
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      );
    },
  );
}
