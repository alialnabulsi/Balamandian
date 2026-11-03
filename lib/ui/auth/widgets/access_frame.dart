import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/asset_icon.dart';
import 'access_heading.dart';
import '../../onboarding/widgets/startup_flow.dart';

class AccessFrame extends StatelessWidget {
  const AccessFrame({
    super.key,
    required this.title,
    this.description,
    required this.label,
    required this.child,
    this.step,
  });
  final String title, label;
  final String? description;
  final int? step;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final nav = StartupNavigation.of(context),
        palette = StartupPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, box) {
          final safe = MediaQuery.paddingOf(context);
          final w = box.maxWidth, h = box.maxHeight;
          // Use the full display height for responsive type even while a keyboard is open.
          final short = MediaQuery.sizeOf(context).height <= 780;
          final gutter = StartupTokens.gutter(w);
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _AccessArcs(
                      Theme.of(context).colorScheme.primary
                          .withValues(alpha: .1),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: h),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        math.max(18, safe.top),
                        gutter,
                        math.max(24, safe.bottom + 18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppIconButton(
                                icon: 'arrow-left',
                                label: 'Back',
                                onPressed: nav.busy ? null : nav.back,
                              ),
                              Flexible(
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: StartupTokens.text(
                                    12,
                                    20,
                                    weight: FontWeight.w500,
                                    color: palette.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                          if (step != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Semantics(
                                label: 'Account setup: step $step of 2',
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: const Color(0xffb98b20),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 34,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: step == 2
                                            ? const Color(0xffb98b20)
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .outline,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          AccessHeading(
                            title: title,
                            description: description,
                            setup: step == 2,
                            short: short,
                            narrow: w <= 360,
                          ),
                          Expanded(child: child),
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
  }
}

class _AccessArcs extends CustomPainter {
  const _AccessArcs(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 440, size.height / 900);
    final paint = Paint()
      ..color = color
      ..strokeWidth = .6
      ..style = PaintingStyle.stroke;
    for (final offset in [0.0, 20.0, 40.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(340 + offset, -50)
          ..cubicTo(240 + offset, 90, 600 + offset, 200, 390 + offset, 450)
          ..cubicTo(180 + offset, 700, 210 + offset, 730, 510 + offset, 940),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AccessArcs oldDelegate) => color != oldDelegate.color;
}
