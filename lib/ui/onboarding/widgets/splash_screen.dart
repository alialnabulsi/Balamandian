import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../routing/startup_destination.dart';
import '../../core/themes/startup_tokens.dart';
import '../../core/ui/copy_entrance.dart';
import '../../core/ui/decorative_art.dart';
import 'startup_flow.dart';
import 'splash_loading_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.hold = false,
    this.nextDestination = StartupDestination.campus,
  });
  final bool hold;
  // A future startup policy can select entry here without changing the view.
  final StartupDestination nextDestination;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _advanced = false;
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: StartupTokens.splashDuration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _scheduleAdvance();
        });

  void _scheduleAdvance() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.hold || _advanced) return;
      final nav = StartupNavigation.of(context);
      if (nav.busy) return;
      _advanced = true;
      nav.navigate(widget.nextDestination);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    if (reduced && _progress.isAnimating) _progress.stop();
    _progress.duration = reduced
        ? const Duration(milliseconds: 250)
        : StartupTokens.splashDuration;
    if (_progress.isCompleted) {
      _scheduleAdvance();
    } else if (!_progress.isAnimating) {
      _progress.forward();
    }
    // Observe pending changes so an already completed stroke can advance later.
    StartupNavigation.of(context);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: StartupTokens.blue,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          children: [
            Positioned(
              top: -.06 * height,
              right: -.05 * width,
              child: DecorativeArt.rays(
                width: width * 1.25,
                height: height * .75,
                color: const Color(0xff2b70b0),
                opacity: .48,
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  math.max(76, MediaQuery.paddingOf(context).top),
                  24,
                  148,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SplashLoadingLogo(
                          progress: reducedMotionProgress(context),
                        ),
                        const SizedBox(height: 26),
                        CopyEntrance(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 200),
                          child: Text(
                            'Balamandian',
                            style: StartupTokens.text(
                              (width * .09).clamp(32, 42),
                              (width * .09).clamp(32, 42) * 1.15,
                              color: Colors.white,
                              weight: FontWeight.w700,
                              spacing: -1.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CopyEntrance(
                          duration: const Duration(milliseconds: 600),
                          delay: const Duration(milliseconds: 350),
                          child: Text(
                            'Your campus, connected.',
                            style: StartupTokens.text(
                              17,
                              25,
                              color: const Color(0xffe2effb),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Animation<double> reducedMotionProgress(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .reduceMotion
      ? const AlwaysStoppedAnimation(1)
      : _progress;
}
