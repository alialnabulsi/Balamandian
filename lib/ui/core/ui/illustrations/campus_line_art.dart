import 'package:flutter/material.dart';

/// Original, transparent campus artwork; never a crop of a UI reference.
class CampusLineArt extends StatelessWidget {
  const CampusLineArt({
    super.key,
    this.width = 224,
    this.height = 112,
    this.color,
  });
  static const asset = 'assets/branding/campus-stories.png';
  final double width, height;
  final Color? color;
  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: width,
    height: height,
    fit: BoxFit.contain,
    cacheWidth: 1024,
    color: color,
    colorBlendMode: color == null ? null : BlendMode.srcIn,
    excludeFromSemantics: true,
  );
}
