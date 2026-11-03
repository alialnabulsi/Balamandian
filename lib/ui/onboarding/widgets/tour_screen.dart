import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../routing/startup_destination.dart';
import '../../core/themes/startup_tokens.dart';
import '../../core/ui/action_button.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/copy_entrance.dart';
import '../../core/ui/decorative_art.dart';
import 'startup_flow.dart';
import 'tour_artwork.dart';
import 'tour_copy.dart';
import 'tour_progress.dart';

class TourScreen extends StatelessWidget {
  const TourScreen({super.key, required this.index});
  final int index;
  @override
  Widget build(BuildContext context) {
    final nav = StartupNavigation.of(context);
    var swipeDistance = 0.0;
    void go(int i) => nav.navigate(StartupDestination.values[i + 1]);
    void next() => index < 2
        ? go(index + 1)
        : nav.navigate(StartupDestination.gettingStarted);
    void previous() {
      if (index > 0) go(index - 1);
    }

    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent ||
              HardwareKeyboard.instance.isAltPressed ||
              HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            next();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            previous();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onHorizontalDragStart: (_) => swipeDistance = 0,
          onHorizontalDragUpdate: (details) =>
              swipeDistance += details.primaryDelta ?? 0,
          onHorizontalDragEnd: (details) {
            if (swipeDistance.abs() < 55) return;
            if (swipeDistance < 0) {
              next();
            } else {
              previous();
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth, h = constraints.maxHeight;
              final narrow = w <= 360, short = h <= 780, tiny = h <= 700;
              final gutter = StartupTokens.gutter(w);
              final safe = MediaQuery.paddingOf(context);
              final top = math.max(short ? 12.0 : 18.0, safe.top);
              final bottom = short
                  ? math.max(16.0, safe.bottom)
                  : math.max(26.0, safe.bottom + 18);
              final artHeight = index == 0
                  ? (tiny
                        ? 270.0
                        : short
                        ? 310.0
                        : (h * .45).clamp(300.0, 416.0))
                  : (tiny
                        ? 245.0
                        : narrow
                        ? 286.0
                        : short
                        ? 280.0
                        : (h * .42).clamp(260.0, 386.0));
              final footerHeight = (tiny ? 2 : 12) + 48 + (short ? 6 : 14) + 54;
              return Stack(
                children: [
                  if (index == 0)
                    Positioned.fill(
                      child: ExcludeSemantics(
                        child: Stack(
                          children: [
                            Positioned(
                              left: -130,
                              bottom: 55,
                              child: DecorativeArt.rays(
                                width: 290,
                                height: 300,
                                color: Theme.of(context).colorScheme.primary,
                                opacity: .045,
                              ),
                            ),
                            const Positioned(
                              right: -20,
                              top: 70,
                              child: DecorativeArt.olive(
                                width: 122,
                                color: StartupTokens.green,
                                opacity: .14,
                                rotation: -18,
                              ),
                            ),
                            const Positioned(
                              right: -12,
                              bottom: 155,
                              child: DecorativeArt.olive(
                                width: 134,
                                color: StartupTokens.green,
                                opacity: .12,
                                rotation: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, top, 0, bottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: gutter),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: BalamandianBrand(narrow: narrow),
                                ),
                                TextButton(
                                  onPressed: nav.busy
                                      ? null
                                      : () => nav.navigate(
                                          StartupDestination.gettingStarted,
                                        ),
                                  child: Text(
                                    'Skip',
                                    style: StartupTokens.text(
                                      14,
                                      20,
                                      weight: FontWeight.w600,
                                      color: StartupPalette.of(context).muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: math.max(
                                0,
                                h - top - bottom - 48 - footerHeight,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    index == 0 ? 0 : gutter - 8,
                                    index == 0
                                        ? 8
                                        : tiny
                                        ? 0
                                        : short
                                        ? 8
                                        : 20,
                                    index == 0 ? 0 : gutter - 8,
                                    index == 0
                                        ? 8
                                        : short
                                        ? 6
                                        : 16,
                                  ),
                                  child: TourArtwork(
                                    index: index,
                                    width: index == 0 ? w : w - 2 * gutter + 16,
                                    height: artHeight,
                                    compact: narrow || short,
                                    tiny: tiny,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    gutter,
                                    4,
                                    gutter,
                                    tiny ? 2 : 10,
                                  ),
                                  child: CopyEntrance(
                                    key: ValueKey(index),
                                    child: TourCopy(
                                      index: index,
                                      width: w,
                                      height: h,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              tiny ? 2 : 12,
                              gutter,
                              0,
                            ),
                            child: Column(
                              children: [
                                TourProgress(
                                  index: index,
                                  narrow: narrow,
                                  onSelected: nav.busy ? null : go,
                                ),
                                SizedBox(height: short ? 6 : 14),
                                ActionButton(
                                  label: index == 2
                                      ? 'Get started'
                                      : 'Continue',
                                  onPressed: nav.busy ? null : next,
                                  background: index == 0
                                      ? StartupTokens.yellow
                                      : index == 1
                                      ? const Color(0xff2f6c22)
                                      : null,
                                  foreground: index == 0
                                      ? const Color(0xff3e3100)
                                      : index == 1
                                      ? Colors.white
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    liveRegion: true,
                    label:
                        'Step ${index + 1} of 3: ${TourProgress.names[index]}',
                    child: const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
