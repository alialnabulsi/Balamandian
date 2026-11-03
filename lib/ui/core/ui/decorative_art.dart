import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'brand.dart';

class DecorativeArt extends StatefulWidget {
  const DecorativeArt.olive({
    super.key,
    required this.width,
    this.height,
    required this.color,
    this.opacity = 1,
    this.rotation = 0,
  }) : rays = false;
  const DecorativeArt.rays({
    super.key,
    required this.width,
    required this.height,
    required this.color,
    this.opacity = 1,
    this.rotation = 0,
  }) : rays = true;
  final bool rays;
  final double width, opacity, rotation;
  final double? height;
  final Color color;
  @override
  State<DecorativeArt> createState() => _DecorativeArtState();
}

class _DecorativeArtState extends State<DecorativeArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.rays ? 14 : 10),
    value: widget.rays ? 4 / 14 : .2,
  );
  bool _reduced = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    if (_reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          child: Opacity(
            opacity: widget.opacity,
            child: SizedBox(
              width: widget.width,
              height: widget.height ?? widget.width / 3,
              child: widget.rays
                  ? SvgPicture.asset(
                      '${StartupAssets.root}/illustrations/sun-rays.svg',
                      colorFilter: ColorFilter.mode(
                        widget.color,
                        BlendMode.srcIn,
                      ),
                    )
                  : Image.asset(
                      '${StartupAssets.root}/illustrations/olive-branch.png',
                      fit: BoxFit.contain,
                      color: widget.color,
                      colorBlendMode: BlendMode.srcIn,
                    ),
            ),
          ),
          builder: (context, child) {
            final t = _reduced
                ? 0.0
                : (1 - math.cos(_controller.value * 2 * math.pi)) / 2;
            return Transform.translate(
              offset: Offset(0, -3 * t),
              child: Transform.rotate(
                angle:
                    (widget.rotation + (_reduced ? 0 : -1.5 + 3 * t)) *
                    math.pi /
                    180,
                alignment: widget.rays
                    ? const Alignment(.6, .8)
                    : const Alignment(-.4, .6),
                child: child,
              ),
            );
          },
        ),
      ),
    ),
  );
}
