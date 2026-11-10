import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/auth_session.dart';
import '../../../routing/shell_destination.dart';
import '../../core/ui/navigation/app_account_drawer.dart';
import '../../core/ui/navigation/app_bottom_bar.dart';
import '../../core/ui/navigation/balamandian_top_bar.dart';
import '../../core/ui/quick_actions/expandable_quick_actions.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.location,
    this.user,
  });

  final StatefulNavigationShell navigationShell;
  final String location;
  final AuthUser? user;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _select(ShellDestination destination) {
    _scaffoldKey.currentState?.closeDrawer();
    if (destination.branchIndex case final index?) {
      widget.navigationShell.goBranch(
        index,
        initialLocation:
            index == widget.navigationShell.currentIndex ||
            destination == ShellDestination.home,
      );
    } else {
      context.go(destination.path);
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: _scaffoldKey,
    appBar: BalamandianTopBar(
      onAccount: () => _scaffoldKey.currentState?.openDrawer(),
      onSearch: () => _comingSoon('Search'),
      onNotifications: () => _comingSoon('Notifications'),
      onMessages: () => _comingSoon('Messages'),
    ),
    drawer: AppAccountDrawer(
      selected: ShellDestination.fromPath(widget.location),
      onSelected: _select,
      email: widget.user?.institutionalEmail,
      sisId: widget.user?.sisUserId,
    ),
    body: SafeArea(top: false, bottom: false, child: widget.navigationShell),
    bottomNavigationBar: AppBottomBar(
      selected: ShellDestination.fromPath(widget.location),
      onSelected: _select,
      onCreate: () => _comingSoon('Create'),
    ),
    floatingActionButton: ExpandableQuickActions(
      navigationId: widget.location,
      actions: [
        for (final destination in [
          ShellDestination.guide,
          ShellDestination.ai,
          ShellDestination.tools,
        ])
          QuickAction(
            label: destination.label,
            icon: destination.icon,
            onSelected: () => _select(destination),
          ),
      ],
    ),
  );
}
