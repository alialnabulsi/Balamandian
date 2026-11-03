import 'package:flutter/material.dart';

import '../themes/startup_tokens.dart';

abstract final class StartupAssets {
  static const root = 'assets/onboarding';
  static String image(String name) => '$root/images/$name.png';
}

class UniversityCrest extends StatelessWidget {
  const UniversityCrest({super.key, this.size = 38, this.decorative = false});
  final double size;
  final bool decorative;

  @override
  Widget build(BuildContext context) => Semantics(
    image: !decorative,
    label: decorative ? null : 'University of Balamand crest',
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: ColoredBox(
          color: StartupTokens.yellow,
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: size * 3.17,
            minWidth: size * 3.17,
            child: Image.asset(
              StartupAssets.image('uob-logo'),
              width: size * 3.17,
              height: size,
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    ),
  );
}

class BalamandianBrand extends StatelessWidget {
  const BalamandianBrand({super.key, this.narrow = false});
  final bool narrow;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      UniversityCrest(size: narrow ? 32 : 38),
      SizedBox(width: narrow ? 6 : 8),
      Text(
        'Balamandian',
        textScaler: TextScaler.noScaling,
        style: StartupTokens.text(
          narrow ? 21 : 23,
          32,
          weight: FontWeight.w700,
          spacing: -1.1,
        ),
      ),
    ],
  );
}
