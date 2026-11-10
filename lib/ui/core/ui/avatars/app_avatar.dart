import 'package:flutter/material.dart';

/// No invented initials or photo: unavailable or failed images use a neutral icon.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.image, this.size = 36});

  final ImageProvider? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: scheme.primaryContainer,
          child: image == null
              ? Icon(
                  Icons.person_outline_rounded,
                  color: scheme.onPrimaryContainer,
                  size: size * .6,
                )
              : Image(
                  image: image!,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) => Icon(
                    Icons.person_outline_rounded,
                    color: scheme.onPrimaryContainer,
                    size: size * .6,
                  ),
                ),
        ),
      ),
    );
  }
}
