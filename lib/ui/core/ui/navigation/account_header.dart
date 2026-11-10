import 'package:flutter/material.dart';

import '../avatars/app_avatar.dart';

class AccountHeader extends StatelessWidget {
  const AccountHeader({super.key, this.email, this.sisId, this.avatar});

  final String? email, sisId;
  final ImageProvider? avatar;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAvatar(image: avatar, size: 56),
        const SizedBox(height: 16),
        Text('Your account', style: Theme.of(context).textTheme.titleLarge),
        if (email != null) ...[
          const SizedBox(height: 6),
          Text(email!, style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (sisId != null) ...[
          const SizedBox(height: 4),
          Text('SIS ID: $sisId', style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}
