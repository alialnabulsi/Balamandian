import 'package:flutter/material.dart';

import '../../themes/shell_tokens.dart';
import '../avatars/app_avatar.dart';
import '../buttons/app_icon_button.dart';

class BalamandianTopBar extends StatelessWidget implements PreferredSizeWidget {
  const BalamandianTopBar({
    super.key,
    required this.onAccount,
    required this.onSearch,
    required this.onNotifications,
    required this.onMessages,
    this.avatar,
    this.notificationBadge,
    this.messageBadge,
  });

  final VoidCallback onAccount, onSearch, onNotifications, onMessages;
  final ImageProvider? avatar;
  final String? notificationBadge, messageBadge;

  @override
  Size get preferredSize => const Size.fromHeight(ShellTokens.toolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    titleSpacing: 4,
    toolbarHeight: preferredSize.height,
    title: Row(
      children: [
        AppIconButton(
          tooltip: 'Open account menu',
          onPressed: onAccount,
          child: AppAvatar(image: avatar, size: 32),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Balamandian',
              maxLines: 1,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -.8,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    ),
    actions: [
      AppIconButton(
        tooltip: 'Search',
        icon: Icons.search_rounded,
        onPressed: onSearch,
      ),
      AppIconButton(
        tooltip: 'Notifications',
        icon: Icons.notifications_none_rounded,
        badgeLabel: notificationBadge,
        onPressed: onNotifications,
      ),
      AppIconButton(
        tooltip: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
        badgeLabel: messageBadge,
        onPressed: onMessages,
      ),
      const SizedBox(width: 4),
    ],
  );
}
