import 'package:flutter/material.dart';

import 'startup_tokens.dart';

abstract final class ShellTokens {
  static const controlRadius = 14.0;
  static const tapSize = StartupTokens.tapSize;
  static const actionSize = 56.0;
  static const toolbarHeight = 64.0;
  static const bottomBarHeight = 80.0;
  static const menuDuration = Duration(milliseconds: 280);
}

/// The filled brand action stays blue with a white foreground in both themes.
@immutable
class ShellPalette extends ThemeExtension<ShellPalette> {
  const ShellPalette({required this.action, required this.onAction});

  final Color action, onAction;

  static ShellPalette of(BuildContext context) =>
      Theme.of(context).extension<ShellPalette>()!;

  @override
  ShellPalette copyWith({Color? action, Color? onAction}) => ShellPalette(
    action: action ?? this.action,
    onAction: onAction ?? this.onAction,
  );

  @override
  ShellPalette lerp(covariant ShellPalette? other, double t) => other == null
      ? this
      : ShellPalette(
          action: Color.lerp(action, other.action, t)!,
          onAction: Color.lerp(onAction, other.onAction, t)!,
        );
}
