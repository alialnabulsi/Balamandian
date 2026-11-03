import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/action_button.dart';
import '../../core/ui/form_message.dart';
import '../../onboarding/widgets/startup_flow.dart';
import '../view_models/auth_ui_controller.dart';
import '../view_models/profile_view_model.dart';
import 'access_frame.dart';
import 'auth_field.dart';
import 'profile_photo_control.dart';
import 'university_details_card.dart';

class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({super.key, this.pickPhoto});
  final PhotoPicker? pickPhoto;
  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _bio = TextEditingController();
  late final _model = ProfileViewModel(pickPhoto: widget.pickPhoto);
  bool _submitting = false;
  @override
  void dispose() {
    _bio.dispose();
    _model.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitting ||
        _model.readingPhoto ||
        StartupNavigation.of(context).busy) {
      return;
    }
    _submitting = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      AuthUiScope.of(
        context,
      ).submitProfile(ProfileDraft(bio: _bio.text.trim(), photo: _model.photo));
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = AuthUiScope.of(context), nav = StartupNavigation.of(context);
    return AccessFrame(
      title: 'A little about you',
      description:
          'Add your photo and bio. Your university details will come from SIS.',
      label: 'First-time setup',
      step: 2,
      child: ListenableBuilder(
        listenable: _model,
        builder: (context, child) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (host.formError != null) ...[
              FormMessage(host.formError!),
              const SizedBox(height: 19),
            ],
            ProfilePhotoControl(
              model: _model,
              disabled: nav.busy,
              identity: host.identity,
            ),
            if (_model.photoError != null) ...[
              const SizedBox(height: 19),
              FormMessage(_model.photoError!, compact: true),
            ],
            const SizedBox(height: 19),
            AuthField(
              label: 'Bio',
              hint: 'Your interests, your clubs, a little about you…',
              controller: _bio,
              enabled: !nav.busy,
              multiline: true,
              maxLength: 240,
              optional: true,
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: _bio,
              builder: (context, value, child) => Text(
                '${value.text.characters.length} / 240',
                textAlign: TextAlign.right,
                style: StartupTokens.text(
                  11,
                  16,
                  color: StartupPalette.of(context).muted,
                ),
              ),
            ),
            const SizedBox(height: 19),
            UniversityDetailsCard(identity: host.identity),
            const Spacer(),
            const SizedBox(height: 19),
            ActionButton(
              label: 'Finish setup',
              icon: 'check',
              pending: host.pending,
              onPressed: nav.busy || _model.readingPhoto ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
