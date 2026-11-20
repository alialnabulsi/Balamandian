import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../domain/models/profile_models.dart';
import '../../themes/app_tokens.dart';
import 'member_avatar.dart';

/// The border frames identity; it does not imply stories or unread content.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.identity,
    required this.loadAvatar,
    this.size = AppTokens.avatarLarge,
    this.onEdit,
    this.showEditIndicator = true,
  });
  final PublicUserIdentity identity;
  final Future<Uint8List> Function(String) loadAvatar;
  final double size;
  final VoidCallback? onEdit;
  final bool showEditIndicator;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size + 8,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary.withValues(alpha: .22)),
            ),
            child: Semantics(
              image: true,
              button: identity.avatarPath != null || onEdit != null,
              label:
                  '${identity.displayName} profile picture${identity.avatarPath == null ? '' : '. Open photo'}',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: identity.avatarPath == null
                    ? onEdit
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AvatarPreview(
                            identity: identity,
                            loadAvatar: loadAvatar,
                          ),
                        ),
                      ),
                child: MemberAvatar(
                  identity: identity,
                  loadAvatar: loadAvatar,
                  size: size,
                ),
              ),
            ),
          ),
          if (onEdit != null && showEditIndicator)
            Positioned(
              right: 0,
              bottom: 0,
              child: SizedBox.square(
                dimension: 48,
                child: IconButton(
                  tooltip: 'Edit profile photo',
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.primary,
                    side: BorderSide(color: scheme.surface, width: 3),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AvatarPreview extends StatefulWidget {
  const AvatarPreview({
    super.key,
    required this.identity,
    required this.loadAvatar,
  });
  final PublicUserIdentity identity;
  final Future<Uint8List> Function(String) loadAvatar;
  @override
  State<AvatarPreview> createState() => _AvatarPreviewState();
}

class _AvatarPreviewState extends State<AvatarPreview> {
  late final _image = widget.loadAvatar(widget.identity.avatarPath!);
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(title: const Text('Profile photo')),
    body: SafeArea(
      child: Center(
        child: FutureBuilder<Uint8List>(
          future: _image,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This photo is unavailable. Please try again later.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const CircularProgressIndicator(
                semanticsLabel: 'Loading photo',
              );
            }
            return InteractiveViewer(
              minScale: 1,
              maxScale: 3,
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                semanticLabel: '${widget.identity.displayName} profile photo',
              ),
            );
          },
        ),
      ),
    ),
  );
}
