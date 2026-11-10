import 'dart:async';

import 'package:flutter/widgets.dart';

import 'native_splash_handoff.dart';

/// Non-splash destinations release Android's overlay after their own first
/// frame. The router's initial URI may still describe an earlier destination.
class NativeSplashReveal extends StatefulWidget {
  const NativeSplashReveal({super.key, required this.child});
  final Widget child;

  @override
  State<NativeSplashReveal> createState() => _NativeSplashRevealState();
}

class _NativeSplashRevealState extends State<NativeSplashReveal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(NativeSplashHandoff.reveal());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
