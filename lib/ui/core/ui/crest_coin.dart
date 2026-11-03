import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../themes/startup_tokens.dart';
import 'brand.dart';

class CrestCoin extends StatefulWidget {
  const CrestCoin({super.key, this.size = 132});
  final double size;
  @override
  State<CrestCoin> createState() => _CrestCoinState();
}

class _CrestCoinState extends State<CrestCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
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
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'University of Balamand crest',
    child: AnimatedBuilder(
      animation: _controller,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color(0xffd3a717), offset: Offset(0, 2)),
            BoxShadow(
              color: Color(0x26052d5d),
              offset: Offset(0, 12),
              blurRadius: 30,
            ),
          ],
        ),
        child: UniversityCrest(size: widget.size, decorative: true),
      ),
      builder: (context, child) {
        final t = ((_controller.value * 2000 - 100) / 1900).clamp(0.0, 1.0);
        // CSS applies its easing independently between the key poses.
        final first = StartupTokens.coinCurve.transform(
          (t / .74).clamp(0.0, 1.0),
        );
        final last = StartupTokens.coinCurve.transform(
          ((t - .74) / .26).clamp(0.0, 1.0),
        );
        final y = t < .74 ? -35 + 725 * first : 690 + 30 * last;
        final z = t < .74 ? -9 + 11 * first : 2 * (1 - last);
        final dy = t < .74 ? 12 - 17 * first : -5 * (1 - last);
        final angle = y * math.pi / 180;
        final back = math.cos(angle) < 0;
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 1 / 900)
          ..rotateY(angle)
          ..rotateZ(z * math.pi / 180)
          ..translateByDouble(0, dy, back ? -3 : 3, 1);
        if (back) matrix.rotateY(math.pi);
        return Opacity(
          opacity: (t / .16).clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: child,
          ),
        );
      },
    ),
  );
}
