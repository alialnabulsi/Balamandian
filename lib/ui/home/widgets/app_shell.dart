import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/auth_session.dart';
import '../../auth/view_models/session_view_model.dart';
import '../../auth/widgets/logout_dialog.dart';
import '../../auth/widgets/sign_in_prompt.dart';
import '../../../routing/startup_destination.dart';
import '../../../routing/shell_destination.dart';
import '../../core/ui/navigation/app_account_drawer.dart';
import '../../core/ui/navigation/app_bottom_bar.dart';
import '../../core/ui/navigation/balamandian_top_bar.dart';
import '../../core/ui/quick_actions/expandable_quick_actions.dart';
import '../../profile/view_models/current_identity_view_model.dart';
import '../../core/ui/avatars/member_avatar.dart';
import '../../core/ui/measure_size.dart';
import '../../core/ui/navigation/bottom_chrome_scope.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.location,
    required this.session,
    required this.identity,
    required this.mapNavigationFocus,
  });

  final StatefulNavigationShell navigationShell;
  final String location;
  final SessionViewModel session;
  final CurrentIdentityViewModel identity;
  final ValueListenable<bool> mapNavigationFocus;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _logoutFlow = false;
  bool _signInFlow = false;
  double _bottomHeight = 0;

  bool get _guest => widget.session.status == SessionStatus.unauthenticated;

  void _signIn() {
    _scaffoldKey.currentState?.closeDrawer();
    context.go(StartupDestination.signIn.path);
  }

  Future<void> _promptSignIn(String feature) async {
    if (_signInFlow) return;
    _signInFlow = true;
    try {
      final signIn = await showDialog<bool>(
        context: context,
        builder: (_) => SignInPrompt(feature: feature),
      );
      if (mounted && _guest && signIn == true) _signIn();
    } finally {
      _signInFlow = false;
    }
  }

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
    if (_guest && destination != ShellDestination.tools) {
      unawaited(_promptSignIn(destination.label));
      return;
    }
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
    if (_guest) {
      unawaited(_promptSignIn(feature));
      return;
    }
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
    ]),
    builder: (context, _) {
      if (widget.session.user == null &&
          !(_guest &&
              (widget.location == ShellDestination.tools.path ||
                  widget.location == '/tools/todo' ||
                  widget.location == '/tools/gpa' ||
                  widget.location == '/tools/notes' ||
                  widget.location == '/tools/lost-found' ||
                  widget.location == '/tools/scheduler' ||
                  widget.location.split('?').first == '/tools/calendar' ||
                  widget.location.startsWith('/tools/notes/')))) {
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
                      onSearch: () {
                        if (_guest) {
                          unawaited(_promptSignIn('member search'));
                        } else {
                          context.push('/members');
                        }
                      },
                      onNotifications: () => _comingSoon('Notifications'),
                      onMessages: () => _comingSoon('Messages'),
                    ),
              drawer: AppAccountDrawer(
                selected: ShellDestination.fromPath(widget.location),
                onSelected: _select,
                onLogout: widget.session.busy ? null : _logout,
                onSignIn: _guest ? _signIn : null,
                email: widget.session.user?.institutionalEmail,
                sisId: widget.session.user?.sisUserId,
                displayName: _guest
                    ? 'Guest'
                    : widget.identity.profile?.identity.displayName,
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
                        onCreate: () => _comingSoon('Create'),
                      ),
                    ),
              floatingActionButton: widget.location == '/map'
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
