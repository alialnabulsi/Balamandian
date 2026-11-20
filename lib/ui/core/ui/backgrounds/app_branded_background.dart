import 'package:flutter/material.dart';

import 'campus_backdrop.dart';

enum AppBackgroundVariant { canvas, card, architecture }

/// Original artwork extracted unchanged from the approved Home SVG.
/// MainApp installs a canvas above the router; transparent routes inherit it.
class AppBrandedBackground extends StatelessWidget {
  const AppBrandedBackground({
    super.key,
    required this.child,
    this.variant = AppBackgroundVariant.canvas,
  });
  static const asset = 'assets/branding/campus-pattern.jpg';
  final Widget child;
  final AppBackgroundVariant variant;
  @override
  Widget build(BuildContext context) {
    if (variant == AppBackgroundVariant.canvas &&
        context.dependOnInheritedWidgetOfExactType<_BackgroundScope>() !=
            null) {
      return child;
    }
    final scheme = Theme.of(context).colorScheme;
    if (variant == AppBackgroundVariant.architecture) {
      return _BackgroundScope(child: CampusBackdrop(child: child));
    }
    final dark = scheme.brightness == Brightness.dark;
    return _BackgroundScope(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          image: DecorationImage(
            image: const AssetImage(asset),
            // Natural 360 x 778 tile: repeat instead of stretching on tablets.
            repeat: ImageRepeat.repeat,
            alignment: Alignment.topCenter,
            scale: variant == AppBackgroundVariant.card ? 1.2 : 1,
            opacity: dark ? .6 : .72,
            colorFilter: dark
                ? const ColorFilter.matrix([
                    -1,
                    0,
                    0,
                    0,
                    255,
                    0,
                    -1,
                    0,
                    0,
                    255,
                    0,
                    0,
                    -1,
                    0,
                    255,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ])
                : null,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _BackgroundScope extends InheritedWidget {
  const _BackgroundScope({required super.child});
  @override
  bool updateShouldNotify(_BackgroundScope oldWidget) => false;
}
