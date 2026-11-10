import 'package:flutter/material.dart';

/// One source for shell locations, labels, icons and persistent branch indices.
enum ShellDestination {
  home('/', 'Home', Icons.home_outlined, Icons.home_rounded, branchIndex: 0),
  map('/map', 'Map', Icons.map_outlined, Icons.map_rounded, branchIndex: 1),
  market(
    '/market',
    'Market',
    Icons.storefront_outlined,
    Icons.storefront_rounded,
    branchIndex: 2,
  ),
  profile(
    '/profile',
    'Profile',
    Icons.person_outline_rounded,
    Icons.person_rounded,
    branchIndex: 3,
  ),
  guide('/guide', 'Guide', Icons.menu_book_outlined, Icons.menu_book_rounded),
  ai('/ai', 'AI', Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
  tools('/tools', 'Tools', Icons.grid_view_outlined, Icons.grid_view_rounded),
  settings(
    '/settings',
    'Settings',
    Icons.settings_outlined,
    Icons.settings_rounded,
  );

  const ShellDestination(
    this.path,
    this.label,
    this.icon,
    this.selectedIcon, {
    this.branchIndex,
  });

  final String path, label;
  final IconData icon, selectedIcon;
  final int? branchIndex;

  static const tabs = [home, map, market, profile];
  static const drawer = [home, map, profile, guide, ai, tools, settings];
  static const auxiliary = [guide, ai, tools, settings];

  static ShellDestination fromPath(String path) => values.firstWhere(
    (destination) =>
        destination != home &&
        (path == destination.path || path.startsWith('${destination.path}/')),
    orElse: () => home,
  );
}
