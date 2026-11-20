import 'package:flutter/material.dart';

/// Official initials when known; a neutral icon while identity is unavailable.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.image, this.name, this.size = 36});

  final ImageProvider? image;
  final double size;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts =
        name
            ?.trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList() ??
        <String>[];
    final initials = parts.isEmpty
        ? ''
        : '${parts.first.characters.first}${parts.length > 1 ? parts.last.characters.first : ''}'
              .toUpperCase();
    final fallback = initials.isEmpty
        ? Icon(
            Icons.person_outline_rounded,
            color: scheme.onPrimaryContainer,
            size: size * .6,
          )
        : Center(
            child: Text(
              initials,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: size * .32,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          );
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: scheme.primaryContainer,
          child: image == null
              ? fallback
              : Image(
                  image: image!,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) => fallback,
                ),
        ),
      ),
    );
  }
}
