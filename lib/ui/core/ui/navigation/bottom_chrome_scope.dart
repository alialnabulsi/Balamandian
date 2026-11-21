import 'package:flutter/widgets.dart';

/// Actual shell height excluded from the body, including the system inset.
class BottomChromeScope extends InheritedWidget {
  const BottomChromeScope({
    super.key,
    required this.height,
    required super.child,
  });
  final double height;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BottomChromeScope>()?.height ??
      0;

  @override
  bool updateShouldNotify(BottomChromeScope oldWidget) =>
      height != oldWidget.height;
}
