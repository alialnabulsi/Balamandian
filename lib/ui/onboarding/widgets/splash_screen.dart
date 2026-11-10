import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../routing/startup_destination.dart';
import '../../core/themes/startup_tokens.dart';
import '../../core/ui/decorative_art.dart';
import 'native_splash_handoff.dart';
import 'splash_entrance.dart';
import 'splash_loading_logo.dart';
import 'startup_flow.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _advanced = false, _preparing = false, _revealed = false;
  bool _reduced = false, _visible = true, _foreground = true;
  Rect? _nativeIcon;
  late final AnimationController _progress =
      AnimationController(
        vsync: this,
        duration: StartupTokens.splashDuration,
        animationBehavior: AnimationBehavior.preserve,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _scheduleAdvance();
      });
  late final _stroke = _progress.drive(
    CurveTween(curve: const Interval(.08, 1)),
  );
  late final _shapes = _progress.drive(
    CurveTween(curve: const Interval(0, .22, curve: Curves.easeOutCubic)),
  );
  late final _title = _progress.drive(
    CurveTween(curve: const Interval(.10, .38, curve: Curves.easeOut)),
  );
  late final _subtitle = _progress.drive(
    CurveTween(curve: const Interval(.17, .45, curve: Curves.easeOut)),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  Future<void> _prepare() async {
    final nativeLayout = NativeSplashHandoff.prepare();
    await precacheImage(const AssetImage(SplashLoadingLogo.asset), context);
    final layout = await nativeLayout;
    if (mounted) {
      setState(() => _nativeIcon = layout);
      // Submit the stable, matching logo before asking Android to uncover it.
      await WidgetsBinding.instance.endOfFrame;
    }
    await NativeSplashHandoff.reveal();
    if (!mounted) return;
    setState(() => _revealed = true);
    _syncMotion();
  }

  void _scheduleAdvance() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.hold || _advanced || !_foreground || !_visible) {
        return;
      }
      final nav = StartupNavigation.of(context);
      if (nav.busy) return;
      _advanced = true;
      nav.navigate(widget.nextDestination);
    });
  }

  void _syncMotion() {
    if (!_revealed || !_foreground || !_visible) {
      _progress.stop();
    } else if (_progress.isCompleted) {
      _scheduleAdvance();
    } else if (!_progress.isAnimating) {
      _progress.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    _visible = TickerMode.valuesOf(context).enabled;
    _progress.duration = _reduced
        ? const Duration(milliseconds: 250)
        : StartupTokens.splashDuration;
    // A held splash also presents session validation outside the onboarding
    // shell. Only advancing onboarding splashes depend on its navigation state.
    if (!widget.hold) StartupNavigation.of(context);
    if (!_preparing) {
      _preparing = true;
      unawaited(_prepare());
    }
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progress.dispose();
    super.dispose();
  }

  Animation<double> _motion(Animation<double> animation) =>
      _reduced && _revealed ? const AlwaysStoppedAnimation(1) : animation;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: StartupTokens.blue,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final box = context.findRenderObject() as RenderBox;
        final origin = box.hasSize
            ? box.localToGlobal(Offset.zero)
            : Offset.zero;
        final icon =
            _nativeIcon?.shift(-origin) ??
            Rect.fromCenter(
              center: Offset(width / 2, height / 2),
              width: 288,
              height: 288,
            );
        final logoSize = icon.width * SplashLoadingLogo.inkFraction + 24;
        return Stack(
          children: [
            Positioned(
              top: -.06 * height,
              right: -.05 * width,
              child: SplashEntrance(
                progress: _motion(_shapes),
                offset: 12,
                child: DecorativeArt.rays(
                  width: width * 1.25,
                  height: height * .75,
                  color: const Color(0xff2b70b0),
                  opacity: .48,
                ),
              ),
            ),
            Positioned(
              left: icon.center.dx - logoSize / 2,
              top: icon.center.dy - logoSize / 2,
              child: SplashLoadingLogo(
                assetSize: icon.width,
                progress: _motion(_stroke),
              ),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  math.max(
                    MediaQuery.paddingOf(context).top,
                    icon.center.dy + logoSize / 2 + 26,
                  ),
                  24,
                  math.max(24, MediaQuery.paddingOf(context).bottom),
                ),
                child: Column(
                  children: [
                    SplashEntrance(
                      progress: _motion(_title),
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
                    SplashEntrance(
                      progress: _motion(_subtitle),
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
          ],
        );
      },
    ),
  );
}
