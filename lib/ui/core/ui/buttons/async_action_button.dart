import 'package:flutter/material.dart';

import 'stable_action_label.dart';

/// Reserves space for both labels and keeps feedback local to the action.
class AsyncActionButton extends StatelessWidget {
  const AsyncActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.running = false,
    this.runningLabel,
    this.outlined = false,
    this.style,
  });
  final String label;
  final String? runningLabel;
  final VoidCallback? onPressed;
  final bool running, outlined;
  final ButtonStyle? style;
  @override
  Widget build(BuildContext context) {
    final caption = runningLabel ?? label;
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 16,
            child: running
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const SizedBox(),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: StableActionLabel(
              label: running ? caption : label,
              labels: [label, caption],
            ),
          ),
        ],
      ),
    );
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
    ).merge(style);
    return Semantics(
      liveRegion: running,
      label: running ? caption : label,
      button: true,
      enabled: !running && onPressed != null,
      excludeSemantics: true,
      onTap: running ? null : onPressed,
      child: outlined
          ? OutlinedButton(
              onPressed: running ? null : onPressed,
              style: buttonStyle,
              child: child,
            )
          : FilledButton(
              onPressed: running ? null : onPressed,
              style: buttonStyle,
              child: child,
            ),
    );
  }
}
