import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/repositories/profile_repository.dart';
import '../view_models/edit_profile_view_model.dart';
import 'profile_editor_form.dart';
import 'profile_tokens.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.repository});
  final ProfileRepository repository;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _model = EditProfileViewModel(repository: widget.repository);
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => PopScope(
      canPop: !_model.saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit profile'),
          actions: [
            TextButton(
              onPressed: _model.saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ProfileTokens.maxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(ProfileTokens.gutter),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ProfileEditorForm(
                model: _model,
                onSaved: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated')),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
