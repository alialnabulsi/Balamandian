import 'package:flutter/material.dart';

import 'dart:async';

import '../../../data/repositories/profile_repository.dart';
import '../../profile/view_models/edit_profile_view_model.dart';
import '../../profile/widgets/profile_editor_form.dart';

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
  const AccountSetupScreen({
    super.key,
    this.pickPhoto,
    this.repository,
    this.onCompleted,
  });
  final PhotoPicker? pickPhoto;
  final ProfileRepository? repository;
  final VoidCallback? onCompleted;
  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _bio = TextEditingController();
  late final _model = ProfileViewModel(pickPhoto: widget.pickPhoto);
  bool _submitting = false;
  EditProfileViewModel? _editor;
  @override
  void initState() {
    super.initState();
    if (widget.repository case final repository?) {
      _editor = EditProfileViewModel(
        repository: repository,
        pickPhoto: widget.pickPhoto,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_editor!.initialize());
      });
    }
  }

  @override
  void dispose() {
    _bio.dispose();
    _model.dispose();
    _editor?.dispose();
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
    if (_editor case final editor?) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !editor.saving) widget.onCompleted?.call();
        },
        child: AccessFrame(
          title: 'A little about you',
          description:
              'Add a photo and bio, or jump straight into campus life.',
          label: 'Personalize your profile',
          expandChild: false,
          onBack: () {
            if (!editor.saving) widget.onCompleted?.call();
          },
          child: ProfileEditorForm(
            model: editor,
            onSaved: widget.onCompleted!,
            onSkip: widget.onCompleted,
          ),
        ),
      );
    }
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
              maxLength: 250,
              optional: true,
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: _bio,
              builder: (context, value, child) => Text(
                '${value.text.runes.length} / 250',
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
