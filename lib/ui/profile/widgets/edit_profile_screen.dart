import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../core/ui/backgrounds/app_branded_background.dart';
import '../view_models/edit_profile_view_model.dart';
import 'profile_editor_form.dart';
import 'profile_tokens.dart';
import 'profile_save_bar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.repository});
  final ProfileRepository repository;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _model = EditProfileViewModel(repository: widget.repository);
  bool _discarding = false, _allowPop = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_model.initialize());
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_model.busy || _discarding) return;
    if (!_model.hasChanges) {
      Navigator.pop(context);
      return;
    }
    _discarding = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'Your unsaved biography and photo changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    _discarding = false;
    if (mounted && discard == true) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _saved() {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => PopScope(
      canPop: _allowPop || (!_model.busy && !_model.hasChanges),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: AppBrandedBackground(
        variant: AppBackgroundVariant.architecture,
        child: Scaffold(
          bottomNavigationBar: _model.profile == null
              ? null
              : ProfileSaveBar(model: _model, onSaved: _saved),
          appBar: AppBar(
            title: const Text('Edit profile'),
            leading: BackButton(onPressed: _model.busy ? null : _leave),
            actions: [
              TextButton(
                onPressed: _model.busy ? null : _leave,
                child: const Text('Cancel'),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ProfileTokens.maxWidth,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ProfileEditorForm(
                    model: _model,
                    onSaved: _saved,
                    showSave: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
