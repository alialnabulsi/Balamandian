import 'package:flutter/material.dart';

import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/loading/delayed_loading.dart';
import 'profile_skeleton.dart';

class ProfileLoadState extends StatelessWidget {
  const ProfileLoadState({
    super.key,
    this.error,
    this.onRetry,
    this.loading = false,
    this.members = false,
    this.editor = false,
    this.emptyTitle = 'No members yet',
    this.emptyMessage = 'Find people in your university community.',
  });
  final String? error;
  final VoidCallback? onRetry;
  final bool loading, members, editor;
  final String emptyTitle, emptyMessage;
  @override
  Widget build(BuildContext context) => loading
      ? DelayedLoading(
          height: members ? 420 : 500,
          child: members
              ? const MemberListSkeleton()
              : editor
              ? const ProfileEditorSkeleton()
              : const ProfileSkeleton(),
        )
      : ContentState(
          title: error == null
              ? emptyTitle
              : members
              ? 'Could not load members'
              : 'Profile unavailable',
          message: error ?? emptyMessage,
          icon: error == null
              ? Icons.people_outline_rounded
              : Icons.cloud_off_rounded,
          onRetry: error == null ? null : onRetry,
        );
}
