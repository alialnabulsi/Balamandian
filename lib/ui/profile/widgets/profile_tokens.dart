import 'package:flutter/material.dart';

import '../../core/themes/app_tokens.dart';

abstract final class ProfileTokens {
  static const gutter = AppTokens.gutter;
  static const maxWidth = 680.0;
  static const avatarSize = 80.0;
  static const radius = AppTokens.controlRadius;
  static const nameFontSize = 22.0;
  static const verificationSize = 18.0;
  static const identityGap = 16.0;
  static const biographyGap = 4.0;
  static const actionsGap = 12.0;
  // Protect the scroll viewport, rather than just adding scrollable space.
  // The shell's original 56px button and 16px bottom offset stay unchanged.
  static const quickActionViewportInset = 80.0;
  static const contentBottomPadding = 28.0;
  static const floatingClearance =
      quickActionViewportInset + contentBottomPadding;
  static ButtonStyle actionStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: scheme.primary.withValues(
        alpha: scheme.brightness == Brightness.dark ? .15 : .07,
      ),
      foregroundColor: scheme.primary,
      disabledBackgroundColor: scheme.primary.withValues(alpha: .09),
      disabledForegroundColor: scheme.primary,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
