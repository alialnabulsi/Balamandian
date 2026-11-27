import 'package:flutter/material.dart';

import '../../core/ui/feedback/content_state.dart';
import '../../core/ui/buttons/async_action_button.dart';
import '../view_models/notes_session.dart';

class NotesAccessPanel extends StatelessWidget {
  const NotesAccessPanel({
    super.key,
    required this.access,
    required this.onSignIn,
    required this.onRetry,
  });
  final NotesAccess access;
  final VoidCallback onSignIn, onRetry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ContentState(
        icon: Icons.note_alt_outlined,
        title: switch (access) {
          NotesAccess.guest => 'Sign in to My Notes',
          NotesAccess.loading => 'Checking account eligibility…',
          NotesAccess.profileError => 'Account eligibility unavailable',
          _ => 'Student and advisor accounts',
        },
        message: switch (access) {
          NotesAccess.guest =>
            'Your notes and drawings stay private to your account.',
          NotesAccess.loading => 'Waiting for your university profile.',
          NotesAccess.profileError =>
            'Retry your profile to check your access.',
          _ => 'My Notes requires a student or advisor role.',
        },
        onRetry: access == NotesAccess.profileError ? onRetry : null,
      ),
      if (access == NotesAccess.guest)
        AsyncActionButton(label: 'Sign in', onPressed: onSignIn),
    ],
  );
}
