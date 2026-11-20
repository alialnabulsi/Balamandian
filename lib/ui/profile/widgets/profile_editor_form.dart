import 'package:flutter/material.dart';

import '../../auth/view_models/auth_ui_controller.dart';
import '../../auth/widgets/profile_photo_control.dart';
import '../../core/ui/avatars/member_avatar.dart';
import '../../core/ui/form_message.dart';
import '../view_models/edit_profile_view_model.dart';
import 'profile_biography_field.dart';
import 'profile_load_state.dart';

class ProfileEditorForm extends StatefulWidget {
  const ProfileEditorForm({
    super.key,
    required this.model,
    required this.onSaved,
    this.onSkip,
  });
  final EditProfileViewModel model;
  final VoidCallback onSaved;
  final VoidCallback? onSkip;
  @override
  State<ProfileEditorForm> createState() => _ProfileEditorFormState();
}

class _ProfileEditorFormState extends State<ProfileEditorForm> {
  final _bio = TextEditingController();
  bool _initialized = false;
  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (await widget.model.save() && mounted) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final model = widget.model, profile = model.profile;
      if (!_initialized && profile != null) {
        _bio.text = model.biography;
        _initialized = true;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (model.loading)
            const ProfileLoadState(loading: true)
          else if (profile == null)
            ProfileLoadState(error: model.error, onRetry: model.initialize)
          else ...[
            ProfilePhotoControl(
              model: model.photo,
              disabled: model.busy,
              identity: UniversityIdentity(name: profile.identity.displayName),
              existingPhoto:
                  !model.removeExisting && profile.identity.avatarPath != null
                  ? MemberAvatar(
                      identity: profile.identity,
                      loadAvatar: model.avatar,
                      size: 76,
                    )
                  : null,
              onRemove: model.removePhoto,
            ),
            if (model.photo.photoError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FormMessage(model.photo.photoError!),
              ),
            const SizedBox(height: 24),
            ProfileBiographyField(
              controller: _bio,
              enabled: !model.busy,
              onChanged: (v) => model.biography = v,
            ),
            const SizedBox(height: 24),
            ProfileLockedIdentity(
              displayName: profile.identity.displayName,
              username: profile.identity.username,
            ),
            const SizedBox(height: 24),
            if (model.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FormMessage(model.error!),
              ),
            FilledButton(
              onPressed: model.busy ? null : _save,
              child: Text(model.saving ? 'Saving…' : 'Save changes'),
            ),
          ],
          if (widget.onSkip != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: model.saving ? null : widget.onSkip,
                child: const Text('Skip for now'),
              ),
            ),
        ],
      );
    },
  );
}

class ProfileLockedIdentity extends StatelessWidget {
  const ProfileLockedIdentity({
    super.key,
    required this.displayName,
    required this.username,
  });
  final String displayName, username;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'University identity',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(displayName),
      const SizedBox(height: 4),
      Text(
        '@$username',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      const Text(
        'Your official name and username are managed by Balamandian using verified university details.',
      ),
    ],
  );
}
