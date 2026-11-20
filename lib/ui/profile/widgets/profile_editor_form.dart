import 'package:flutter/material.dart';

import '../../auth/view_models/auth_ui_controller.dart';
import '../../auth/widgets/profile_photo_control.dart';
import '../../core/ui/avatars/member_avatar.dart';
import '../../core/ui/buttons/async_action_button.dart';
import '../../core/ui/form_message.dart';
import '../view_models/edit_profile_view_model.dart';
import 'profile_biography_section.dart';
import 'profile_load_state.dart';
import 'profile_locked_identity.dart';

class ProfileEditorForm extends StatefulWidget {
  const ProfileEditorForm({
    super.key,
    required this.model,
    required this.onSaved,
    this.onSkip,
    this.showSave = true,
  });
  final EditProfileViewModel model;
  final VoidCallback onSaved;
  final VoidCallback? onSkip;
  final bool showSave;
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
            const ProfileLoadState(loading: true, editor: true)
          else if (profile == null)
            ProfileLoadState(
              loading: model.error == null,
              editor: true,
              error: model.error,
              onRetry: model.initialize,
            )
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
                      size: 96,
                    )
                  : null,
              onRemove: model.removePhoto,
            ),
            if (model.photo.photoError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FormMessage(model.photo.photoError!),
              ),
            const SizedBox(height: 20),
            const Divider(height: 32),
            ProfileBiographySection(
              controller: _bio,
              enabled: !model.busy,
              onChanged: (value) => model.biography = value,
            ),
            const Divider(height: 32),
            ProfileLockedIdentity(
              displayName: profile.identity.displayName,
              username: profile.identity.username,
            ),
            const SizedBox(height: 20),
            if (widget.showSave && model.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FormMessage(model.error!),
              ),
            if (widget.showSave)
              AsyncActionButton(
                label: 'Save changes',
                running: model.saving,
                runningLabel: model.savingLabel,
                onPressed: model.busy ? null : _save,
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
