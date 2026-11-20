import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/app_tokens.dart';

/// Measures possible labels using the actual font and accessibility scaler.
/// Reserves their largest width without duplicate hidden text or semantics.
class StableActionLabel extends StatelessWidget {
  const StableActionLabel({
    super.key,
    required this.label,
    required this.labels,
  });
  final String label;
  final List<String> labels;
  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var width = 0.0;
    for (final value in labels) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textScaler: scaler,
        textDirection: direction,
      )..layout();
      width = math.max(width, painter.width.ceilToDouble());
      painter.dispose();
    }
    return SizedBox(
      width: width,
      child: AnimatedSwitcher(
        duration: AppTokens.motion(context),
        child: Text(label, key: ValueKey(label), textAlign: TextAlign.center),
      ),
    );
  }
}
