import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/body_copy.dart';

class TourCopy extends StatelessWidget {
  const TourCopy({
    super.key,
    required this.index,
    required this.width,
    required this.height,
  });
  final int index;
  final double width, height;
  static const titles = [
    'Find your way.\nFeel at home.',
    'Your people.\nYour campus.',
    'Your Campus\nAssistant',
  ];
  static const descriptions = [
    'Explore campus, discover buildings, and get to know your next stop.',
    'Find your community, join a club, and share the moments in between.',
    'Access smart campus tools, navigation, and your assistant. A little help for every day.',
  ];
  @override
  Widget build(BuildContext context) {
    final narrow = width <= 360, short = height <= 780, tiny = height <= 700;
    final titleSize = tiny
        ? 29.0
        : narrow
        ? 30.0
        : short
        ? 32.0
        : (width * .086).clamp(30.0, 38.0);
    final style = StartupTokens.text(
      narrow ? 14 : 15,
      narrow ? 22 : 23,
      color: StartupPalette.of(context).muted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          namesRoute: true,
          child: Text(
            titles[index],
            style: StartupTokens.text(
              titleSize,
              titleSize * 1.12,
              weight: FontWeight.w700,
              spacing: narrow ? -1.2 : -1.5,
            ),
          ),
        ),
        SizedBox(
          height: tiny
              ? 9
              : short
              ? 11
              : 15,
        ),
        BodyCopy(descriptions[index], style: style),
      ],
    );
  }
}
