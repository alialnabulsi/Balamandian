import 'package:flutter/material.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/profile_models.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';
import '../view_models/user_profile_view_model.dart';
import 'member_list_panel.dart';
import 'member_list_header.dart';
import 'profile_tokens.dart';

/// Tabs retain independent searches, pagination and scroll positions.
class MemberListScreen extends StatefulWidget {
  const MemberListScreen({
    super.key,
    required this.repository,
    required this.kind,
    this.userId,
  });
  final ProfileRepository repository;
  final MemberListKind kind;
  final String? userId;
  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen>
    with TickerProviderStateMixin {
  late final _profile = UserProfileViewModel(
    repository: widget.repository,
    userId: widget.userId,
  );
  TabController? _controller;
  TabController get _tabs => _controller!;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppTokens.sheet;
    if (_controller == null || _tabs.animationDuration != duration) {
      final index =
          _controller?.index ??
          (widget.kind == MemberListKind.following ? 1 : 0);
      _controller?.removeListener(_changed);
      _controller?.dispose();
      _controller = TabController(
        length: 2,
        initialIndex: index,
        animationDuration: duration,
        vsync: this,
      )..addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    _profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _profile,
    builder: (context, _) {
      final discover = widget.kind == MemberListKind.discover;
      final profile = _profile.profile;
      return AppBrandedBackground(
        variant: AppBackgroundVariant.architecture,
        child: Scaffold(
          appBar: MemberListHeader(
            discover: discover,
            tabs: _tabs,
            username: profile?.identity.username,
            followers: profile?.followersCount,
            following: profile?.followingCount,
          ),
          body: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ProfileTokens.maxWidth,
                ),
                child: discover
                    ? MemberListPanel(
                        repository: widget.repository,
                        kind: MemberListKind.discover,
                      )
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          MemberListPanel(
                            repository: widget.repository,
                            kind: MemberListKind.followers,
                            userId: widget.userId,
                            active: _tabs.index == 0,
                          ),
                          MemberListPanel(
                            repository: widget.repository,
                            kind: MemberListKind.following,
                            userId: widget.userId,
                            active: _tabs.index == 1,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
