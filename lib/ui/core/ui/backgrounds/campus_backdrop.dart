import 'package:flutter/material.dart';

import '../illustrations/campus_line_art.dart';

/// Stationary architectural variation of the shared Balamandian canvas.
class CampusBackdrop extends StatelessWidget {
  const CampusBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeTop = MediaQuery.paddingOf(context).top;
    final ink = scheme.primary.withValues(
      alpha: scheme.brightness == Brightness.dark ? .15 : .10,
    );
    return ColoredBox(
      color: scheme.surface,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: safeTop + 220,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    children: [
                      Positioned(
                        left: box.maxWidth * .08,
                        right: box.maxWidth * .04,
                        top: safeTop + 54,
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: [0, .62, .78, 1],
                          ).createShader(rect),
                          child: CampusLineArt(
                            width: box.maxWidth,
                            height: 180,
                            color: ink,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -48,
                        top: safeTop + 24,
                        child: Transform.rotate(
                          angle: -.2,
                          child: Image.asset(
                            'assets/onboarding/illustrations/olive-branch.png',
                            width: 210,
                            height: 80,
                            fit: BoxFit.contain,
                            cacheWidth: 640,
                            color: ink,
                            colorBlendMode: BlendMode.srcIn,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ],
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
