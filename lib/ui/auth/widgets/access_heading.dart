import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/body_copy.dart';

class AccessHeading extends StatelessWidget {
  const AccessHeading({
    super.key,
    required this.title,
    required this.description,
    required this.setup,
    required this.short,
    required this.narrow,
  });
  final String title, description;
  final bool setup, short, narrow;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      0,
      setup || short ? 24 : 32,
      0,
      setup
          ? 24
          : short
          ? 20
          : 24,
    ),
    child: Column(
      children: [
        if (!setup) ...[
          UniversityCrest(size: short ? 56 : 65),
          SizedBox(height: short ? 13 : 16),
        ],
        Text(
          'UNIVERSITY OF BALAMAND',
          textAlign: TextAlign.center,
          style: StartupTokens.text(
            9,
            18,
            weight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
            spacing: 1.7,
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          namesRoute: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: StartupTokens.text(
              narrow ? 27 : 30,
              narrow ? 35 : 38,
              weight: FontWeight.w700,
              spacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        BodyCopy(
          description,
          textAlign: TextAlign.center,
          style: StartupTokens.text(
            14,
            22,
            color: StartupPalette.of(context).muted,
          ),
        ),
      ],
    ),
  );
}
