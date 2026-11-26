import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/profile_models.dart';
import '../../community/widgets/community_actions.dart';
import '../../community/widgets/community_feed.dart';
import '../../community/widgets/community_stories.dart';
import '../../core/themes/app_tokens.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';
import '../../core/ui/form_message.dart';
import '../view_models/user_profile_view_model.dart';
import 'profile_header.dart';
import 'profile_identity_section.dart';
import 'profile_actions.dart';
import 'profile_posts_section.dart';
import 'profile_load_state.dart';
import 'account_information_sheet.dart';
import 'profile_share_sheet.dart';
import 'profile_tokens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    this.userId,
    this.community,
  });
  final ProfileRepository repository;
  final CommunityRepository? community;
  final String? userId;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _model = UserProfileViewModel(
    repository: widget.repository,
    userId: widget.userId,
  );
  @override
  void initState() {
    super.initState();
    widget.community?.addListener(_revalidate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          _model.load(
            refresh: widget.community != null && widget.userId != null,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    widget.community?.removeListener(_revalidate);
    _model.dispose();
    super.dispose();
  }

  void _revalidate() {
    if (mounted && widget.userId != null) {
      unawaited(_model.load(refresh: true, revalidate: true));
    }
  }

  Future<void> _safety(
    UserProfile profile,
    CommunityRepository community,
  ) async {
    final id = profile.identity.id;
    final action = await communityMenu<String>(
      context,
      child: CommunityMenuBody(
        title: profile.identity.displayName,
        children: const [
          CommunityMenuOption(
            'Mute posts or stories',
            Icons.volume_off_outlined,
            'mute',
          ),
          CommunityMenuOption('Block account', Icons.block_outlined, 'block'),
          CommunityMenuOption('Report profile', Icons.flag_outlined, 'report'),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'report') {
      await communityMenu<void>(
        context,
        child: CommunityReportSheet(
          repository: community,
          kind: 'profile',
          id: id,
        ),
      );
      return;
    }
    if (action == 'mute') {
      await communityMenu<void>(
        context,
        child: CommunityMuteSheet(
          repository: community,
          memberId: id,
          name: profile.identity.displayName,
        ),
      );
      return;
    }
    if (await communityConfirm(
          context,
          'Block this account?',
          'Both accounts lose access to each other’s community content and any follow relationship is removed.',
        ) &&
        mounted) {
      await communityCommand(context, () async {
        await community.mutate('relationships/$id/block');
        community.invalidate();
        if (mounted && context.canPop()) context.pop();
      });
    }
  }

  void _account() => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AccountInformationSheet(
      profile: _model.profile!,
      loadAvatar: _model.avatar,
    ),
  );
  void _share() => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ProfileShareSheet(
      username: _model.profile!.identity.username,
      identity: _model.profile!.identity,
      loadAvatar: _model.avatar,
    ),
  );
  @override
  Widget build(BuildContext context) => AppBrandedBackground(
    variant: AppBackgroundVariant.architecture,
    child: ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final profile = _model.profile;
        final community = widget.community;
        final locked =
            profile != null &&
            profile.privateAccount &&
            !profile.isSelf &&
            !profile.isFollowing;
        return Scaffold(
          appBar: ProfileHeader(
            username: profile?.identity.username,
            canGoBack: widget.userId != null,
            onMenu: () => Scaffold.maybeOf(context)?.openDrawer(),
            onAccount: profile == null ? null : _account,
            onShare: profile == null ? null : _share,
            onSafety: community == null || profile == null || profile.isSelf
                ? null
                : () => _safety(profile, community),
            onDiscover: widget.userId == null || profile?.isSelf == true
                ? () => context.push('/members')
                : null,
          ),
          body: SafeArea(
            top: false,
            child: Padding(
              key: const ValueKey('profile-scroll-clearance'),
              padding: EdgeInsets.only(
                bottom: widget.userId == null
                    ? ProfileTokens.quickActionViewportInset
                    : 0,
              ),
              child: RefreshIndicator(
                onRefresh: () => _model.load(refresh: true),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ProfileTokens.maxWidth,
                    ),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        ProfileTokens.gutter,
                        32,
                        ProfileTokens.gutter,
                        ProfileTokens.contentBottomPadding,
                      ),
                      children: [
                        if (profile == null)
                          ProfileLoadState(
                            loading: _model.loading || _model.error == null,
                            error: _model.error,
                            onRetry: () => _model.load(refresh: true),
                          )
                        else ...[
                          if (_model.loading)
                            const LinearProgressIndicator(
                              semanticsLabel: 'Refreshing profile',
                              minHeight: 2,
                            ),
                          TweenAnimationBuilder<double>(
                            key: ValueKey(profile.identity.id),
                            tween: Tween(begin: 0, end: 1),
                            curve: AppTokens.curve,
                            duration: AppTokens.motion(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ProfileIdentitySection(
                                  profile: profile,
                                  loadAvatar: _model.avatar,
                                  onEdit: () => context.push('/profile/edit'),
                                  onFollowers: locked
                                      ? null
                                      : () => context.push(
                                          '/members/${profile.identity.id}/followers',
                                        ),
                                  onFollowing: locked
                                      ? null
                                      : () => context.push(
                                          '/members/${profile.identity.id}/following',
                                        ),
                                ),
                                if (community != null &&
                                    !profile.isSelf &&
                                    !locked)
                                  CommunityProfileStories(
                                    key: ValueKey(profile.identity.id),
                                    repository: community,
                                    author: profile.identity,
                                    loadAvatar: _model.avatar,
                                  ),
                                const SizedBox(
                                  height: ProfileTokens.actionsGap,
                                ),
                                ProfileActions(
                                  isSelf: profile.isSelf,
                                  isFollowing: profile.isFollowing,
                                  requested: profile.followRequested,
                                  pending: _model.following,
                                  onEdit: () => context.push('/profile/edit'),
                                  onFollow: () async {
                                    await _model.toggleFollow();
                                    if (mounted && _model.error == null) {
                                      community?.invalidate();
                                    }
                                  },
                                  onShare: _share,
                                ),
                                if (_model.error != null) ...[
                                  const SizedBox(height: 12),
                                  FormMessage(_model.error!),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _model.load(refresh: true),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Retry'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 8),
                                child: child,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ProfilePostsSection(
                            count: profile.postsCount,
                            isSelf: profile.isSelf,
                            grid: community == null
                                ? null
                                : CommunityProfileGrid(
                                    repository: community,
                                    userId: profile.identity.id,
                                    own: profile.isSelf,
                                    locked: locked,
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
