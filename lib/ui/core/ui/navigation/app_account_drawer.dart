import 'package:flutter/material.dart';

import '../../../../routing/shell_destination.dart';
import '../buttons/drawer_logout_button.dart';
import 'account_header.dart';

class AppAccountDrawer extends StatelessWidget {
  const AppAccountDrawer({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onLogout,
    this.destinations = ShellDestination.drawer,
    this.email,
    this.sisId,
    this.avatar,
  });

  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelected;
  final VoidCallback? onLogout;
  final List<ShellDestination> destinations;
  final String? email, sisId;
  final ImageProvider? avatar;

  @override
  Widget build(BuildContext context) {
    final index = destinations.indexOf(selected);
    return NavigationDrawer(
      selectedIndex: index < 0 ? null : index,
      onDestinationSelected: (index) => onSelected(destinations[index]),
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              const SizedBox(height: 8),
              DrawerLogoutButton(onPressed: onLogout),
            ],
          ),
        ),
      ),
      children: [
        AccountHeader(email: email, sisId: sisId, avatar: avatar),
        const Divider(indent: 28, endIndent: 28),
        for (final destination in destinations)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
