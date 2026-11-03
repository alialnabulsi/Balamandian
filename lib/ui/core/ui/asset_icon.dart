import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'brand.dart';

class AssetIcon extends StatelessWidget {
  const AssetIcon(this.name, {super.key, this.size = 22, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    '${StartupAssets.root}/icons/$name.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
    colorFilter: ColorFilter.mode(
      color ??
          IconTheme.of(context).color ??
          Theme.of(context).colorScheme.onSurface,
      BlendMode.srcIn,
    ),
  );
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.color,
    this.selected,
  });
  final String icon, label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool? selected;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      isSelected: selected,
      tooltip: label,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        maximumSize: const Size(48, 48),
        padding: EdgeInsets.zero,
        backgroundColor: outlined ? scheme.surface : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: outlined ? BorderSide(color: scheme.outline) : BorderSide.none,
        ),
      ),
      icon: AssetIcon(icon, color: color ?? scheme.primary),
    );
  }
}
