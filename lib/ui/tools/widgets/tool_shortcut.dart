import 'package:flutter/material.dart';

import '../../core/themes/app_tokens.dart';

/// A complete tappable shortcut, with status conveyed visually and to readers.
class ToolShortcut extends StatelessWidget {
  const ToolShortcut({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.availabilityLabel,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? availabilityLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      label: label,
      hint: availabilityLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: availabilityLabel == null
            ? label
            : '$label: $availabilityLabel',
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(AppTokens.touchTarget, 104),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            foregroundColor: theme.colorScheme.primary,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: 32),
                    if (availabilityLabel != null)
                      PositionedDirectional(
                        end: 0,
                        bottom: 0,
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
