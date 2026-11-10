import 'package:flutter/material.dart';

import '../../themes/shell_tokens.dart';

/// A labeled Material icon button with an Android-sized target and badge slot.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.child,
    this.badgeLabel,
  }) : assert((icon == null) != (child == null));

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? child;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(ShellTokens.tapSize),
      padding: const EdgeInsets.all(8),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
    ),
    icon: Badge(
      isLabelVisible: badgeLabel != null,
      label: badgeLabel == null ? null : Text(badgeLabel!),
      child: child ?? Icon(icon),
    ),
  );
}
