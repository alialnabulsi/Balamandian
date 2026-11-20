import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../domain/models/profile_models.dart';
import 'app_avatar.dart';

/// Loads only through the authenticated data boundary. Tokens never enter widgets.
class MemberAvatar extends StatefulWidget {
  const MemberAvatar({
    super.key,
    required this.identity,
    required this.loadAvatar,
    this.size = 40,
  });
  final PublicUserIdentity? identity;
  final Future<Uint8List> Function(String path) loadAvatar;
  final double size;
  @override
  State<MemberAvatar> createState() => _MemberAvatarState();
}

class _MemberAvatarState extends State<MemberAvatar> {
  Future<Uint8List>? _image;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final path = widget.identity?.avatarPath;
    _image = path == null ? null : widget.loadAvatar(path);
  }

  @override
  void didUpdateWidget(MemberAvatar old) {
    super.didUpdateWidget(old);
    if (old.identity?.avatarPath != widget.identity?.avatarPath ||
        old.identity?.id != widget.identity?.id) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _image,
    builder: (context, snapshot) => AppAvatar(
      size: widget.size,
      name: widget.identity?.displayName,
      image: snapshot.hasData ? MemoryImage(snapshot.data!) : null,
    ),
  );
}
