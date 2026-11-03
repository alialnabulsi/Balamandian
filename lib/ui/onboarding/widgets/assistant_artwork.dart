import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/brand.dart';
import 'assistant_preview.dart';
import 'tool_tile.dart';
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
          top: 15,
          left: width * .05,
          child: Container(
            width: width * .9,
            height: width * .9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
        ),
        const Positioned(
          right: -35,
          top: -12,
          child: DecorativeArt.rays(
            width: 220,
            height: 240,
            color: StartupTokens.yellow,
            opacity: .3,
            rotation: -15,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, compact ? 12 : 24, 0, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: width * .73,
                        child: Transform.rotate(
                          angle: -3 * math.pi / 180,
                          child: AssistantPreview(compact: compact, tiny: tiny),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: compact ? -14 : -20,
                    bottom: 0,
                    width: width * .46,
                    child: Image.asset(
                      StartupAssets.image('campus-assistant-robot'),
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomRight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Transform.rotate(
                angle: 2 * math.pi / 180,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ToolTile(
                        icon: 'calendar-dots',
                        label: 'Schedule',
                        compact: compact,
                        tiny: tiny,
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: ToolTile(
                        icon: 'note-pencil',
                        label: 'Notes',
                        compact: compact,
                        tiny: tiny,
                        foreground: StartupPalette.of(context).warning,
                        background: StartupPalette.of(context).warningBg,
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: ToolTile(
                        icon: 'calculator',
                        label: 'GPA',
                        compact: compact,
                        tiny: tiny,
                        foreground: StartupPalette.of(context).success,
                        background: StartupPalette.of(context).successBg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          top: -9,
          left: -4,
          child: DecorativeArt.olive(
            width: 86,
            height: 48,
            color: Color(0xff88aa72),
            rotation: -20,
          ),
        ),
      ],
    ),
  );
}
