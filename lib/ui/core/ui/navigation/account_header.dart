import 'package:flutter/material.dart';

import '../avatars/app_avatar.dart';

class AccountHeader extends StatelessWidget {
  const AccountHeader({
    super.key,
    this.email,
    this.sisId,
    this.avatar,
    this.avatarWidget,
    this.displayName,
    this.username,
  });

  final String? email, sisId;
  final ImageProvider? avatar;
  final Widget? avatarWidget;
  final String? displayName, username;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        avatarWidget ?? AppAvatar(image: avatar, size: 56),
        const SizedBox(height: 16),
        Text(
          displayName ?? 'Your account',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (username != null)
          Text('@$username', style: Theme.of(context).textTheme.bodyMedium),
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
