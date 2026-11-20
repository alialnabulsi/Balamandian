import 'package:flutter/material.dart';

import '../../core/ui/buttons/async_action_button.dart';
import '../../core/ui/form_message.dart';
import '../view_models/edit_profile_view_model.dart';
import 'profile_tokens.dart';

class ProfileSaveBar extends StatelessWidget {
  const ProfileSaveBar({super.key, required this.model, required this.onSaved});
  final EditProfileViewModel model;
  final VoidCallback onSaved;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ProfileTokens.maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (model.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FormMessage(model.error!),
                  ),
                AsyncActionButton(
                  label: 'Save changes',
                  running: model.saving,
                  runningLabel: model.savingLabel,
                  onPressed: model.busy
                      ? null
                      : () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          if (await model.save() && context.mounted) onSaved();
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
