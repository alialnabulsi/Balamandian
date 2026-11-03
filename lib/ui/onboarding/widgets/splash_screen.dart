import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../routing/startup_destination.dart';
import '../../core/themes/startup_tokens.dart';
import '../../core/ui/copy_entrance.dart';
import '../../core/ui/crest_coin.dart';
import '../../core/ui/decorative_art.dart';
import 'startup_flow.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.hold = false});
  final bool hold;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2350),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nav = StartupNavigation.of(context);
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    if (reduced) {
      _progress.value = 1;
    } else if (_progress.value == 0) {
      _progress.forward();
    }
    if (!widget.hold && !nav.busy && (_timer == null || !_timer!.isActive)) {
      _timer = Timer(Duration(milliseconds: reduced ? 250 : 2350), () {
        if (mounted) {
          StartupNavigation.of(context).navigate(StartupDestination.campus);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
                        const CrestCoin(),
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
            Positioned(
              bottom: math.max(40, MediaQuery.paddingOf(context).bottom + 24),
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DecorativeArt.olive(
                    width: 78,
                    height: 44,
                    color: Color(0xff8eb2d5),
                    opacity: .8,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Rooted in Balamand. Made for you.',
                    style: StartupTokens.text(
                      12,
                      20,
                      color: const Color(0xffe2effb),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 40,
                    height: 3,
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, child) => LinearProgressIndicator(
                        value: _progress.value,
                        backgroundColor: const Color(0x30ffffff),
                        color: StartupTokens.yellow,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
