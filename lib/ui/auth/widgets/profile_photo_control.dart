import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/asset_icon.dart';
import '../view_models/auth_ui_controller.dart';
import '../view_models/profile_view_model.dart';

class ProfilePhotoControl extends StatelessWidget {
  const ProfilePhotoControl({
    super.key,
    required this.model,
    required this.disabled,
    this.identity,
  });
  final ProfileViewModel model;
  final bool disabled;
  final UniversityIdentity? identity;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = identity?.name?.trim() ?? '';
    final initials = name.isEmpty
        ? ''
        : name
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part.characters.first)
              .join();
    final blocked = disabled || model.readingPhoto;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: model.preview == null
                ? 'Add profile photo'
                : 'Change profile photo',
            child: InkWell(
              onTap: blocked ? null : model.selectPhoto,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: 76,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primaryContainer,
                        border: Border.all(color: scheme.outline),
                      ),
                      alignment: Alignment.center,
                      child: model.preview != null
                          ? Image.memory(
                              model.preview!,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              cacheWidth: 256,
                              semanticLabel: 'Your selected profile photo',
                            )
                          : initials.isNotEmpty
                          ? Text(
                              initials,
                              style: StartupTokens.text(
                                24,
                                30,
                                weight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            )
                          : AssetIcon('users', size: 32, color: scheme.primary),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 27,
                        height: 27,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary,
                          border: Border.all(
                            width: 2,
                            color: StartupPalette.of(context).canvas,
                          ),
                        ),
                        child: AssetIcon(
                          'camera',
                          size: 16,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your campus face',
                  style: StartupTokens.text(14, 21, weight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: blocked ? null : model.selectPhoto,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        model.readingPhoto
                            ? 'Reading photo…'
                            : model.preview == null
                            ? 'Add a photo'
                            : 'Change photo',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    if (model.preview != null)
                      TextButton(
                        onPressed: blocked ? null : model.removePhoto,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text('Remove photo'),
                      ),
                  ],
                ),
                Text(
                  'Optional · JPG, PNG or WebP · Up to 1 MB',
                  style: StartupTokens.text(
                    11,
                    18,
                    color: StartupPalette.of(context).muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
