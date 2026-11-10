import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/auth_session.dart';
import '../../auth/view_models/session_view_model.dart';
import '../../auth/widgets/logout_dialog.dart';
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
    required this.session,
  });

  final StatefulNavigationShell navigationShell;
  final String location;
  final SessionViewModel session;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _logoutFlow = false;

  Future<void> _logout() async {
    if (_logoutFlow || widget.session.busy) return;
    _logoutFlow = true;
    _scaffoldKey.currentState?.closeDrawer();
    try {
      var choice = await showDialog<LogoutChoice>(
        context: context,
        builder: (_) => const LogoutDialog(),
      );
      while (mounted && choice != null) {
        await widget.session.logout(
          localOnly: choice == LogoutChoice.localOnly,
        );
        if (!mounted || widget.session.status != SessionStatus.authenticated) {
          return;
        }
        choice = await showDialog<LogoutChoice>(
          context: context,
          builder: (_) => LogoutDialog(error: widget.session.error),
        );
      }
    } finally {
      _logoutFlow = false;
    }
  }

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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      if (widget.session.user == null) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: const SizedBox.expand(),
        );
      }
      return PopScope(
        canPop: !widget.session.busy,
        child: Stack(
          children: [
            Scaffold(
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
                onLogout: widget.session.busy ? null : _logout,
                email: widget.session.user?.institutionalEmail,
                sisId: widget.session.user?.sisUserId,
              ),
              body: SafeArea(
                top: false,
                bottom: false,
                child: widget.navigationShell,
              ),
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
            ),
            if (widget.session.busy) ...[
              const Positioned.fill(
                child: ModalBarrier(dismissible: false, color: Colors.black38),
              ),
              const Center(
                child: CircularProgressIndicator(semanticsLabel: 'Logging out'),
              ),
            ],
          ],
        ),
      );
    },
  );
}
