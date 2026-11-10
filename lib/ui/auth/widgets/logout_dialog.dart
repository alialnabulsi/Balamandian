import 'package:flutter/material.dart';

enum LogoutChoice { server, localOnly }

class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key, this.error});
  final String? error;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(error == null ? 'Log out?' : 'Couldn’t log out'),
    content: Text(error ?? 'Are you sure you want to log out of Balamandian?'),
    scrollable: true,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (error != null)
        TextButton(
          onPressed: () => Navigator.pop(context, LogoutChoice.localOnly),
          child: const Text('Sign out on this device'),
        ),
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => Navigator.pop(context, LogoutChoice.server),
        child: Text(error == null ? 'Log out' : 'Retry'),
      ),
    ],
  );
}
