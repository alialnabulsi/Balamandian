import 'package:flutter/material.dart';

import '../../themes/shell_tokens.dart';

class DrawerLogoutButton extends StatelessWidget {
  const DrawerLogoutButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Log out'),
      style: FilledButton.styleFrom(
        alignment: Alignment.centerLeft,
        backgroundColor: scheme.errorContainer,
        foregroundColor: scheme.error,
        minimumSize: const Size(double.infinity, ShellTokens.tapSize),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShellTokens.controlRadius),
        ),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
