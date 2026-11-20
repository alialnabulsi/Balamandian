import 'package:flutter/material.dart';

import '../themes/app_tokens.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.gutter),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(AppTokens.surfaceRadius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: child,
    );
  }
}
