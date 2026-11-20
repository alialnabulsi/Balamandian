import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/profile_repository.dart';
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
  const ProfileScreen({super.key, required this.repository, this.userId});
  final ProfileRepository repository;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_model.load());
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  void _account() => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AccountInformationSheet(profile: _model.profile!),
  );
  void _share() => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        ProfileShareSheet(username: _model.profile!.identity.username),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final profile = _model.profile;
      return Scaffold(
        appBar: ProfileHeader(
          username: profile?.identity.username,
          canGoBack: widget.userId != null,
          onMenu: () => Scaffold.maybeOf(context)?.openDrawer(),
          onAccount: profile == null ? null : _account,
          onShare: profile == null ? null : _share,
        ),
        body: RefreshIndicator(
          onRefresh: () => _model.load(refresh: true),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ProfileTokens.maxWidth,
              ),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  if (profile == null)
                    ProfileLoadState(
                      loading: _model.loading,
                      error: _model.error,
                      onRetry: () => _model.load(refresh: true),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ProfileTokens.gutter,
                        20,
                        ProfileTokens.gutter,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ProfileIdentitySection(
                            profile: profile,
                            loadAvatar: _model.avatar,
                            onFollowers: () => context.push(
                              '/members/${profile.identity.id}/followers',
                            ),
                            onFollowing: () => context.push(
                              '/members/${profile.identity.id}/following',
                            ),
                          ),
                          const SizedBox(height: 20),
                          ProfileActions(
                            isSelf: profile.isSelf,
                            isFollowing: profile.isFollowing,
                            pending: _model.following,
                            onEdit: () => context.push('/profile/edit'),
                            onFollow: () => _model.toggleFollow(),
                            onShare: _share,
                          ),
                          if (profile.isSelf)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextButton.icon(
                                onPressed: () => context.push('/members'),
                                icon: const Icon(Icons.person_search_outlined),
                                label: const Text('Discover members'),
                              ),
                            ),
                          if (_model.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: FormMessage(_model.error!),
                            ),
                        ],
                      ),
                    ),
                    ProfilePostsSection(
                      count: profile.postsCount,
                      isSelf: profile.isSelf,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
