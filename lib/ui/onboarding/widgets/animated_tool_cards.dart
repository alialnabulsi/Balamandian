import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import 'tool_tile.dart';

class AnimatedToolCards extends StatefulWidget {
  const AnimatedToolCards({
    super.key,
    required this.width,
    this.compact = false,
    this.tiny = false,
  });
  final double width;
  final bool compact, tiny;

  @override
  State<AnimatedToolCards> createState() => _AnimatedToolCardsState();
}

class _AnimatedToolCardsState extends State<AnimatedToolCards>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: StartupTokens.toolCycleDuration,
  );
  bool _visible = true, _reduced = false, _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _reduced =
        MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (_visible && _foreground && !_reduced) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = StartupPalette.of(context);
    final tileWidth = (widget.width - 20) / 3;
    final pitch = (widget.width - tileWidth) / 2;
    final labelMeasure = TextPainter(
      text: TextSpan(
        text: 'Schedule',
        style: StartupTokens.text(11, 16, weight: FontWeight.w600),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: tileWidth - 18);
    final tileHeight =
        (widget.tiny
            ? 14
            : widget.compact
            ? 18
            : 26) +
        37 +
        (widget.compact ? 5 : 8) +
        labelMeasure.height +
        2;
    labelMeasure.dispose();
    final height = tileHeight * 1.04 + 12;
    const labels = ['Schedule', 'Notes', 'GPA'];
    const icons = ['calendar-dots', 'note-pencil', 'calculator'];
    // Repeated copies enter/leave beyond the clip. A whole three-card cycle is
    // visually identical at either endpoint, including scale and hop velocity.
    final tiles = <Widget>[];
    for (var slot = -5; slot <= 2; slot++) {
      final tool = (slot + 1) % 3;
      tiles.add(
        SizedBox(
          key: ValueKey('tool-${labels[tool]}-$slot'),
          width: tileWidth,
          child: ToolTile(
            icon: icons[tool],
            label: labels[tool],
            compact: widget.compact,
            tiny: widget.tiny,
            foreground: tool == 1
                ? palette.warning
                : tool == 2
                ? palette.success
                : null,
            background: tool == 1
                ? palette.warningBg
                : tool == 2
                ? palette.successBg
                : null,
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ClipRect(
            child: SizedBox(
              width: widget.width,
              height: height,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final phase = (_reduced ? 0.0 : _controller.value) * 3;
                  final step = phase.floor();
                  final fraction = ((phase - step - .65) / .35).clamp(0.0, 1.0);
                  final move = Curves.easeInOutCubic.transform(fraction);
                  final travel = step + move;
                  final hop = -3 * math.sin(math.pi * move);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < tiles.length; i++)
                        Positioned(
                          left:
                              widget.width / 2 +
                              (i - 5 + travel) * pitch -
                              tileWidth / 2,
                          top: 6,
                          child: Transform.translate(
                            offset: Offset(0, hop),
                            child: Transform.scale(
                              scale:
                                  .94 +
                                  .16 *
                                      (1 -
                                          (i - 5 + travel).abs().clamp(
                                            0.0,
                                            1.0,
                                          )),
                              alignment: Alignment.center,
                              child: tiles[i],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
