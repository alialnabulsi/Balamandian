import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';

/// The original startup canvas and viewport, shared by launch and re-entry.
class StartupFrame extends StatelessWidget {
  const StartupFrame({super.key, required this.child, this.splash = false});
  final Widget child;
  final bool splash;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: splash ? StartupTokens.blue : Theme.of(context).colorScheme.surface,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ClipRect(child: child),
      ),
    ),
  );
}
