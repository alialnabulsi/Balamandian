import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/decorative_art.dart';
import 'assistant_artwork.dart';

class TourArtwork extends StatelessWidget {
  const TourArtwork({
    super.key,
    required this.index,
    required this.height,
    required this.width,
    required this.compact,
    required this.tiny,
  });
  final int index;
  final double height, width;
  final bool compact, tiny;
  @override
  Widget build(BuildContext context) {
    if (index == 2) {
      return AssistantArtwork(width: width, compact: compact, tiny: tiny);
    }
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final scheme = Theme.of(context).colorScheme;
          return Stack(
            clipBehavior: Clip.none,
            children: index == 0
                ? [
                    Positioned(
                      top: 40,
                      right: 8,
                      child: Container(
                        width: 216,
                        height: 216,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primaryContainer,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -36,
                      top: 12,
                      child: DecorativeArt.rays(
                        width: 220,
                        height: 230,
                        color: scheme.primary,
                        opacity: .12,
                        rotation: -18,
                      ),
                    ),
                    Positioned.fill(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black,
                            Colors.black,
                            Colors.transparent,
                          ],
                          stops: [0, .12, .72, 1],
                        ).createShader(bounds),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              StartupAssets.image('onboarding-main-campus'),
                              fit: BoxFit.cover,
                              alignment: const Alignment(-.04, 0),
                              semanticLabel: 'The main University of Balamand campus, with its fountain and central walkway',
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.surface,
                                    scheme.surface.withValues(alpha: 0),
                                    scheme.surface.withValues(alpha: 0),
                                    scheme.surface,
                                  ],
                                  stops: const [0, .08, .92, 1],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Positioned(
                      bottom: 12,
                      left: 20,
                      child: DecorativeArt.olive(
                        width: 94,
                        height: 54,
                        color: Color(0xff7fa36a),
                        rotation: -12,
                      ),
                    ),
                  ]
                : [
                    Positioned(
                      top: 20,
                      right: 18,
                      child: Container(
                        width: 145,
                        height: 145,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: StartupTokens.yellow,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 36,
                      left: 0,
                      right: 0,
                      bottom: 48,
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.elliptical(
                            w * .48,
                            (height - 84) * .34,
                          ),
                          topRight: Radius.elliptical(
                            w * .50,
                            (height - 84) * .31,
                          ),
                          bottomRight: Radius.elliptical(
                            w * .08,
                            (height - 84) * .12,
                          ),
                          bottomLeft: Radius.elliptical(
                            w * .10,
                            (height - 84) * .10,
                          ),
                        ),
                        child: Image.asset(
                          StartupAssets.image('onboarding-community-fair'),
                          fit: BoxFit.cover,
                          alignment: const Alignment(.02, 0),
                          semanticLabel: 'Students gathering at the University of Balamand club fair',
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 4,
                      left: 10,
                      child: DecorativeArt.olive(
                        width: 90,
                        color: Color(0xff7fa36a),
                        rotation: -12,
                      ),
                    ),
                    Positioned(
                      right: 22,
                      bottom: 12,
                      child: Transform.rotate(
                        angle: -18 * math.pi / 180,
                        child: Row(
                          children: List.generate(
                            3,
                            (i) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3.5,
                              ),
                              child: Transform.translate(
                                offset: Offset(0, i == 1 ? 0 : 4),
                                child: Transform.rotate(
                                  angle:
                                      (i == 0
                                          ? 28
                                          : i == 2
                                          ? -28
                                          : 0) *
                                      math.pi /
                                      180,
                                  child: Container(
                                    width: 3,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      color: StartupTokens.green,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
          );
        },
      ),
    );
  }
}
