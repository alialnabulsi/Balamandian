import 'package:flutter/material.dart';

import '../themes/startup_tokens.dart';

class FormMessage extends StatelessWidget {
  const FormMessage(this.message, {super.key, this.compact = false});
  final String message;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: compact ? EdgeInsets.zero : const EdgeInsets.all(12),
        decoration: compact
            ? null
            : BoxDecoration(
                color: scheme.errorContainer,
                border: Border.all(color: scheme.error),
                borderRadius: BorderRadius.circular(14),
              ),
        child: Text(
          message,
          style: StartupTokens.text(
            compact ? 12 : 14,
            compact ? 19 : 22,
            color: scheme.error,
          ),
        ),
      ),
    );
  }
}
