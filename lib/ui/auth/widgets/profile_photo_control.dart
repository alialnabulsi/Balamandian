import 'package:flutter/material.dart';

import '../../core/themes/app_tokens.dart';
import '../../core/ui/avatars/app_avatar.dart';
import '../view_models/auth_ui_controller.dart';
import '../view_models/profile_view_model.dart';

class ProfilePhotoControl extends StatelessWidget {
  const ProfilePhotoControl({
    super.key,
    required this.model,
    required this.disabled,
    this.identity,
    this.existingPhoto,
    this.onRemove,
  });
  final ProfileViewModel model;
  final bool disabled;
  final UniversityIdentity? identity;
  final Widget? existingPhoto;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = disabled || model.readingPhoto;
    final hasPhoto = model.preview != null || existingPhoto != null;
    return Column(
      children: [
        Semantics(
          button: true,
          label: hasPhoto ? 'Change profile photo' : 'Add profile photo',
          child: InkWell(
            onTap: blocked ? null : model.selectPhoto,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 108,
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: .25),
                      ),
                    ),
                    child: model.preview != null
                        ? ClipOval(
                            child: Image.memory(
                              model.preview!,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              cacheWidth: 256,
                              semanticLabel: 'Your selected profile photo',
                            ),
                          )
                        : existingPhoto ??
                              AppAvatar(
                                name: identity?.name,
                                size: AppTokens.avatarLarge,
                              ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                        border: Border.all(color: scheme.surface, width: 3),
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 17,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            TextButton.icon(
              onPressed: blocked ? null : model.selectPhoto,
              icon: model.readingPhoto
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(
                model.readingPhoto
                    ? 'Preparing photo…'
                    : hasPhoto
                    ? 'Change photo'
                    : 'Add a photo',
              ),
            ),
            if (hasPhoto)
              TextButton(
                onPressed: blocked ? null : onRemove ?? model.removePhoto,
                child: const Text('Remove photo'),
              ),
          ],
        ),
        Text(
          'JPG, PNG or WebP · Photos are resized for your profile',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
