import 'package:flutter/material.dart';

abstract final class StartupTokens {
  static const blue = Color(0xff0e569e);
  static const yellow = Color(0xffffcf36);
  static const green = Color(0xff63a042);
  static const navy = Color(0xff031d32);
  static const entryLink = Color(0xff9ecf52);
  static const radius = 14.0;
  static const tapSize = 48.0;
  static const coinDuration = Duration(milliseconds: 1900);
  static const splashDuration = Duration(milliseconds: 2100);
  static const toolCycleDuration = Duration(milliseconds: 7200);
  static const coinCurve = Cubic(.2, .7, .24, 1);
  static const wipeCover = Duration(milliseconds: 360);
  static const wipeExit = Duration(milliseconds: 460);
  static const Curve wipeCurve = _PowerTwoInOut();

  static double gutter(double width) => width <= 360 ? 20 : 24;
  static TextStyle text(
    double size,
    double lineHeight, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double spacing = 0,
  }) => TextStyle(
    fontFamily: 'Inter',
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
  );
}

class _PowerTwoInOut extends Curve {
  const _PowerTwoInOut();
  @override
  double transformInternal(double t) {
    if (t < .5) return 4 * t * t * t;
    final remaining = 1 - t;
    return 1 - 4 * remaining * remaining * remaining;
  }
}

@immutable
class StartupPalette extends ThemeExtension<StartupPalette> {
  const StartupPalette({
    required this.canvas,
    required this.muted,
    required this.actionPressed,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
  });

  final Color canvas,
      muted,
      actionPressed,
      success,
      successBg,
      warning,
      warningBg;
  static StartupPalette of(BuildContext context) =>
      Theme.of(context).extension<StartupPalette>()!;

  @override
  StartupPalette copyWith({
    Color? canvas,
    Color? muted,
    Color? actionPressed,
    Color? success,
    Color? successBg,
    Color? warning,
    Color? warningBg,
  }) => StartupPalette(
    canvas: canvas ?? this.canvas,
    muted: muted ?? this.muted,
    actionPressed: actionPressed ?? this.actionPressed,
    success: success ?? this.success,
    successBg: successBg ?? this.successBg,
    warning: warning ?? this.warning,
    warningBg: warningBg ?? this.warningBg,
  );

  @override
  StartupPalette lerp(covariant StartupPalette? other, double t) {
    if (other == null) return this;
    return StartupPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      actionPressed: Color.lerp(actionPressed, other.actionPressed, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
    );
  }
}
