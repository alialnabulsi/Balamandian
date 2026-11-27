import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/auth_session.dart';
import '../../auth/view_models/session_view_model.dart';
import '../../auth/widgets/logout_dialog.dart';
import '../../../routing/shell_destination.dart';
import '../../core/ui/navigation/app_account_drawer.dart';
import '../../core/ui/navigation/app_bottom_bar.dart';
import '../../core/ui/navigation/balamandian_top_bar.dart';
import '../../core/ui/quick_actions/expandable_quick_actions.dart';
import '../../profile/view_models/current_identity_view_model.dart';
import '../../community/view_models/community_inbox_model.dart';
import '../../community/widgets/community_actions.dart';
import '../../core/ui/avatars/member_avatar.dart';
import '../../core/ui/measure_size.dart';
import '../../core/ui/navigation/bottom_chrome_scope.dart';
import '../../messaging/widgets/messaging_scope.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.location,
    required this.session,
    required this.identity,
    required this.mapNavigationFocus,
    this.inbox,
    this.communityEnabled = false,
  });

  final StatefulNavigationShell navigationShell;
  final String location;
  final SessionViewModel session;
  final CurrentIdentityViewModel identity;
  final ValueListenable<bool> mapNavigationFocus;
  final CommunityInboxModel? inbox;
  final bool communityEnabled;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _logoutFlow = false;
  double _bottomHeight = 0;

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
    listenable: Listenable.merge([
      widget.session,
      widget.identity,
      widget.mapNavigationFocus,
      widget.inbox,
    ]),
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
              resizeToAvoidBottomInset: widget.location != '/map',
              appBar: widget.location == '/profile' || widget.location == '/map'
                  ? null
                  : BalamandianTopBar(
                      avatarWidget: MemberAvatar(
                        identity: widget.identity.profile?.identity,
                        loadAvatar: widget.identity.avatar,
                        size: 32,
                      ),
                      onAccount: () => _scaffoldKey.currentState?.openDrawer(),
                      onSearch: () => context.push('/members'),
                      onNotifications: () => widget.inbox == null
                          ? _comingSoon('Notifications')
                          : context.push('/community/activity'),
                      notificationBadge: (widget.inbox?.unread ?? 0) > 0
                          ? '${widget.inbox!.unread > 99 ? '99+' : widget.inbox!.unread}'
                          : null,
                      onMessages: () =>
                          MessagingScope.maybeOf(context, listen: false) == null
                          ? _comingSoon('Messages')
                          : context.push('/messages'),
                      messageBadge: switch (MessagingScope.maybeOf(context)
                              ?.session
                              .unread ??
                          0) {
                        0 => null,
                        > 99 => '99+',
                        final count => '$count',
                      },
                    ),
              drawer: AppAccountDrawer(
                selected: ShellDestination.fromPath(widget.location),
                onSelected: _select,
                onLogout: widget.session.busy ? null : _logout,
                email: widget.session.user?.institutionalEmail,
                sisId: widget.session.user?.sisUserId,
                displayName: widget.identity.profile?.identity.displayName,
                username: widget.identity.profile?.identity.username,
                avatarWidget: MemberAvatar(
                  identity: widget.identity.profile?.identity,
                  loadAvatar: widget.identity.avatar,
                  size: 56,
                ),
              ),
              body: SafeArea(
                top: false,
                bottom: false,
                child: BottomChromeScope(
                  height:
                      widget.location == '/map' &&
                          widget.mapNavigationFocus.value
                      ? 0
                      : _bottomHeight,
                  child: widget.navigationShell,
                ),
              ),
              bottomNavigationBar:
                  widget.location == '/map' && widget.mapNavigationFocus.value
                  ? null
                  : MeasureSize(
                      onChange: (size) {
                        if (mounted && _bottomHeight != size.height) {
                          setState(() => _bottomHeight = size.height);
                        }
                      },
                      child: AppBottomBar(
                        selected: ShellDestination.fromPath(widget.location),
                        onSelected: _select,
                        onCreate: () => widget.communityEnabled
                            ? openCommunityCreate(context)
                            : _comingSoon('Create'),
                      ),
                    ),
              floatingActionButton:
                  widget.location == '/map' ||
                      (widget.communityEnabled &&
                          widget.location == '/settings') ||
                      (widget.communityEnabled && widget.location == '/')
                  ? null
                  : ExpandableQuickActions(
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
