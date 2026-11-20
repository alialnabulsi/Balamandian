import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileShareSheet extends StatelessWidget {
  const ProfileShareSheet({super.key, required this.username});
  final String username;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Share profile', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        SelectableText(
          '@$username',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Share this username with another Balamandian member. They can find it in Discover members.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () async {
            try {
              await Clipboard.setData(ClipboardData(text: '@$username'));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username copied')),
                );
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not copy. Select the username to copy it.',
                    ),
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy username'),
        ),
      ],
    ),
  );
}
