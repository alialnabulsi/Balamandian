import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget implements PreferredSizeWidget {
  const ProfileHeader({
    super.key,
    required this.username,
    required this.onAccount,
    required this.onShare,
    this.onMenu,
    this.onDiscover,
    this.onSafety,
    this.canGoBack = false,
  });
  final String? username;
  final VoidCallback? onAccount, onShare, onMenu, onDiscover;
  final VoidCallback? onSafety;
  final bool canGoBack;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: canGoBack,
    titleSpacing: canGoBack ? 0 : 20,
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
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
            ],
          ),
        ),
      ),
    ),
    actions: [
      if (onSafety != null)
        IconButton(
          tooltip: 'Profile safety options',
          onPressed: onSafety,
          icon: const Icon(Icons.more_horiz),
        ),
      if (onDiscover != null)
        IconButton(
          tooltip: 'Discover members',
          onPressed: onDiscover,
          icon: const Icon(Icons.person_search_outlined),
        ),
      if (canGoBack)
        IconButton(
          tooltip: 'Share profile',
          onPressed: onShare,
          icon: const Icon(Icons.ios_share_rounded),
        )
      else
        IconButton(
          tooltip: 'Open account menu',
          onPressed: onMenu,
          icon: const Icon(Icons.menu_rounded),
        ),
      const SizedBox(width: 8),
    ],
  );
}
