import 'package:flutter/material.dart';

import '../../core/themes/app_tokens.dart';

/// Three columns at normal phone widths; fewer as available label space shrinks.
class ShortcutGrid extends StatelessWidget {
  const ShortcutGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
      final columns =
          ((constraints.maxWidth + AppTokens.space) /
                  (92 * scale + AppTokens.space))
              .floor()
              .clamp(1, 3);
      final width =
          (constraints.maxWidth - AppTokens.space * (columns - 1)) / columns;
      return Wrap(
        spacing: AppTokens.space,
        runSpacing: AppTokens.space,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
