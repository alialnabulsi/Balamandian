import 'package:flutter/material.dart';

import '../../../../routing/shell_destination.dart';
import 'account_header.dart';

class AppAccountDrawer extends StatelessWidget {
  const AppAccountDrawer({
    super.key,
    required this.selected,
    required this.onSelected,
    this.destinations = ShellDestination.drawer,
    this.email,
    this.sisId,
    this.avatar,
  });

  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelected;
  final List<ShellDestination> destinations;
  final String? email, sisId;
  final ImageProvider? avatar;

  @override
  Widget build(BuildContext context) {
    final index = destinations.indexOf(selected);
    return NavigationDrawer(
      selectedIndex: index < 0 ? null : index,
      onDestinationSelected: (index) => onSelected(destinations[index]),
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
