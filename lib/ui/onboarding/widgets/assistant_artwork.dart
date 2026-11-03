import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/brand.dart';
import 'assistant_preview.dart';
import 'animated_tool_cards.dart';
import '../../core/ui/decorative_art.dart';

class AssistantArtwork extends StatelessWidget {
  const AssistantArtwork({
    super.key,
    required this.width,
    this.compact = false,
    this.tiny = false,
  });
  final bool compact, tiny;
  final double width;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 8,
          left: width * .14,
          child: Container(
            width: width * .72,
            height: width * .65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
        ),
        const Positioned(
          right: 0,
          top: -8,
          child: DecorativeArt.rays(
            width: 176,
            height: 190,
            color: StartupTokens.yellow,
            opacity: .24,
            rotation: -15,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, compact ? 8 : 12, 0, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: width * .76,
                        child: Transform.rotate(
                          angle: -2 * math.pi / 180,
                          child: AssistantPreview(compact: compact, tiny: tiny),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: width * .34,
                    child: Image.asset(
                      StartupAssets.image('campus-assistant-robot'),
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomRight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedToolCards(width: width, compact: true, tiny: tiny),
            ],
          ),
        ),
        const Positioned(
          top: -6,
          left: 0,
          child: DecorativeArt.olive(
            width: 72,
            height: 40,
            color: Color(0xff88aa72),
            rotation: -20,
          ),
        ),
      ],
    ),
  );
}
