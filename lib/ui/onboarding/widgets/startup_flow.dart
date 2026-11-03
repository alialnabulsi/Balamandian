import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/startup_destination.dart';
import '../../auth/view_models/auth_ui_controller.dart';
import '../../core/themes/startup_tokens.dart';
import '../../core/ui/brand.dart';

class StartupNavigation extends InheritedWidget {
  const StartupNavigation({
    super.key,
    required this.busy,
    required this.screen,
    required this.navigate,
    required this.back,
    required super.child,
  });
  final bool busy;
  final StartupDestination screen;
  final ValueChanged<StartupDestination> navigate;
  final VoidCallback back;
  static StartupNavigation of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StartupNavigation>()!;
  @override
  bool updateShouldNotify(StartupNavigation oldWidget) =>
      busy != oldWidget.busy || screen != oldWidget.screen;
}

class StartupFlow extends StatefulWidget {
  const StartupFlow({
    super.key,
    required this.screen,
    required this.child,
    this.onOnboardingCompleted,
  });
  final StartupDestination screen;
  final Widget child;
  final VoidCallback? onOnboardingCompleted;
  @override
  State<StartupFlow> createState() => _StartupFlowState();
}

class _StartupFlowState extends State<StartupFlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wipe = AnimationController(
    vsync: this,
    upperBound: 1.7,
  );
  bool _moving = false, _precached = false;
  Color _wipeColor = StartupTokens.blue;

  bool get _reduced =>
      MediaQuery.disableAnimationsOf(context) ||
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .reduceMotion;
  bool get _busy => _moving || AuthUiScope.of(context).pending;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final name in [
        'onboarding-main-campus',
        'onboarding-community-fair',
        'onboarding-library-evening',
        'campus-assistant-robot',
      ]) {
        unawaited(
          precacheImage(AssetImage(StartupAssets.image(name)), context),
        );
      }
    }
    if (_moving && _reduced && _wipe.isAnimating) _wipe.stop(canceled: false);
  }

  Future<void> _navigate(StartupDestination next) async {
    if (_busy || widget.screen == next) return;
    final leavingTour =
        widget.screen.tourIndex >= 0 &&
        next == StartupDestination.gettingStarted;
    FocusManager.instance.primaryFocus?.unfocus();
    AuthUiScope.of(context).clearMessage();
    setState(() {
      _moving = true;
      _wipeColor = switch (next) {
        StartupDestination.community => StartupTokens.yellow,
        StartupDestination.assistant => StartupTokens.green,
        _ => StartupTokens.blue,
      };
    });
    try {
      if (!_reduced) {
        _wipe.value = 0;
        await _wipe
            .animateTo(
              .8,
              duration: StartupTokens.wipeCover,
              curve: StartupTokens.wipeCurve,
            )
            .orCancel;
      }
      if (!mounted) return;
      context.go(next.path);
      if (leavingTour) widget.onOnboardingCompleted?.call();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (!mounted) return;
      if (!_reduced) {
        await _wipe
            .animateTo(
              1.7,
              duration: StartupTokens.wipeExit,
              curve: StartupTokens.wipeCurve,
            )
            .orCancel;
      }
    } on TickerCanceled {
      /* A removed flow has no further navigation work. */
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  void _back() {
    final previous = switch (widget.screen) {
      StartupDestination.community => StartupDestination.campus,
      StartupDestination.assistant => StartupDestination.community,
      StartupDestination.signIn ||
      StartupDestination.signUp => StartupDestination.gettingStarted,
      StartupDestination.accountSetup => StartupDestination.signUp,
      _ => null,
    };
    if (previous != null) unawaited(_navigate(previous));
  }

  @override
  void dispose() {
    _wipe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = widget.screen;
    final canExit =
        !_busy &&
        (screen == StartupDestination.splash ||
            screen == StartupDestination.gettingStarted ||
            screen == StartupDestination.campus);
    return PopScope(
      canPop: canExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy) _back();
      },
      child: StartupNavigation(
        busy: _busy,
        screen: screen,
        navigate: (next) => unawaited(_navigate(next)),
        back: _back,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            statusBarIconBrightness:
                screen == StartupDestination.splash ||
                    screen == StartupDestination.gettingStarted ||
                    Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarIconBrightness:
                screen == StartupDestination.splash ||
                    Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AbsorbPointer(absorbing: _moving, child: widget.child),
                      if (_moving && !_reduced)
                        IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _wipe,
                            builder: (context, child) => CustomPaint(
                              painter: _WipePainter(_wipe.value, _wipeColor),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WipePainter extends CustomPainter {
  const _WipePainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(0, size.height - progress * size.height * 1.8);
    canvas.scale(size.width / 440, size.height * 1.8 / 1200);
    final path = Path()
      ..moveTo(0, 125)
      ..cubicTo(110, -5, 280, 235, 440, 85)
      ..lineTo(440, 1100)
      ..cubicTo(300, 1215, 130, 1020, 0, 1140)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WipePainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
