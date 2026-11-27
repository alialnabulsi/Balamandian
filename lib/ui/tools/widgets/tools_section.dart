import 'package:flutter/material.dart';

import '../../core/themes/app_tokens.dart';
import '../../core/ui/app_surface.dart';

class ToolsSection extends StatelessWidget {
  const ToolsSection({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.all(AppTokens.space * 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: AppTokens.space * 2),
        child,
      ],
    ),
  );
}
