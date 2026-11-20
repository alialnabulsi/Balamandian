import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget implements PreferredSizeWidget {
  const ProfileHeader({
    super.key,
    required this.username,
    required this.onAccount,
    required this.onShare,
    this.onMenu,
    this.canGoBack = false,
  });
  final String? username;
  final VoidCallback? onAccount, onShare, onMenu;
  final bool canGoBack;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: canGoBack,
    leading: canGoBack
        ? null
        : IconButton(
            tooltip: 'Open account menu',
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded),
          ),
    titleSpacing: 0,
    title: Semantics(
      button: true,
      label: 'About this account',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onAccount,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  username ?? 'Your profile',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
        ),
      ),
    ),
    actions: [
      IconButton(
        tooltip: 'Share profile',
        onPressed: onShare,
        icon: const Icon(Icons.ios_share_rounded),
      ),
      const SizedBox(width: 8),
    ],
  );
}
