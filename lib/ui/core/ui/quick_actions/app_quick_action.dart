import 'package:flutter/material.dart';

import '../../themes/shell_tokens.dart';

class AppQuickAction extends StatelessWidget {
  const AppQuickAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
    this.diameter = 72,
    this.primary = false,
    this.autofocus = false,
  });

  final IconData icon;
  final String tooltip;
  final String? label;
  final VoidCallback onPressed;
  final double diameter;
  final bool primary, autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ShellPalette.of(context);
    final foreground = primary ? palette.onAction : theme.colorScheme.primary;
    return Semantics(
      button: true,
      label: tooltip,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: primary ? palette.action : theme.colorScheme.surface,
          elevation: 4,
          shadowColor: theme.colorScheme.shadow.withValues(alpha: .2),
          shape: CircleBorder(
            side: BorderSide(
              color: primary
                  ? palette.action
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            autofocus: autofocus,
            child: SizedBox.square(
              dimension: diameter,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: foreground, size: 24),
                    if (label != null) ...[
                      const SizedBox(height: 3),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label!,
                            maxLines: 1,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
