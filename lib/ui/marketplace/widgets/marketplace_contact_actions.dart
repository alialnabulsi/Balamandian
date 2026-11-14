import 'package:flutter/material.dart';

class MarketplaceContactActions extends StatelessWidget {
  const MarketplaceContactActions({
    super.key,
    this.onPhone,
    this.onWebsite,
    this.onSocial,
  });
  final VoidCallback? onPhone, onWebsite, onSocial;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      if (onPhone != null)
        OutlinedButton.icon(
          onPressed: onPhone,
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.phone_outlined),
          label: const Text('Phone'),
        ),
      if (onWebsite != null)
        OutlinedButton.icon(
          onPressed: onWebsite,
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.language_rounded),
          label: const Text('Website'),
        ),
      if (onSocial != null)
        OutlinedButton.icon(
          onPressed: onSocial,
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Social page'),
        ),
    ],
  );
}
