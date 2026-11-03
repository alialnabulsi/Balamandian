import 'package:flutter/material.dart';

// Matches the handoff's 34ch copy measure while honoring platform text scaling.
class BodyCopy extends StatelessWidget {
  const BodyCopy(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
  });
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  @override
  Widget build(BuildContext context) {
    final measure = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = measure.width * 34;
    measure.dispose();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}
