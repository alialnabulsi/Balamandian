import 'package:flutter/material.dart';

abstract final class AppTokens {
  static const space = 8.0;
  static const gutter = 20.0;
  static const surfaceRadius = 24.0;
  static const controlRadius = 14.0;
  static const avatarSmall = 48.0;
  static const avatarLarge = 96.0;
  static const touchTarget = 48.0;
  static const micro = Duration(milliseconds: 140);
  static const transition = Duration(milliseconds: 220);
  static const sheet = Duration(milliseconds: 300);
  static const loadingThreshold = Duration(milliseconds: 200);
  static const curve = Curves.easeOutCubic;
  static Duration motion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : transition;
}
