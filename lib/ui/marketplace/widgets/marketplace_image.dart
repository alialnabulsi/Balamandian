import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'marketplace_tokens.dart';

class MarketplaceImage extends StatelessWidget {
  const MarketplaceImage({
    super.key,
    required this.url,
    required this.slug,
    required this.label,
    this.aspectRatio = MarketplaceTokens.imageAspect,
  });
  final String? url;
  final String slug, label;
  final double aspectRatio;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: label,
    excludeSemantics: true,
    child: AspectRatio(
      aspectRatio: aspectRatio,
      child: url == null
          ? MarketplaceLocalImage(slug: slug)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) =>
                  MarketplaceLocalImage(slug: slug),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        MarketplaceLocalImage(slug: slug),
                        const Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Loading place image',
                          ),
                        ),
                      ],
                    ),
            ),
    ),
  );
}

class MarketplaceLocalImage extends StatelessWidget {
  const MarketplaceLocalImage({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context) {
    final asset = MarketplaceTokens.placeholder(slug);
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      );
    }
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, synchronous) =>
          frame != null || synchronous
          ? child
          : SvgPicture.asset(
              '${MarketplaceTokens.imageRoot}/generic.svg',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
      errorBuilder: (context, error, stack) => SvgPicture.asset(
        '${MarketplaceTokens.imageRoot}/generic.svg',
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    );
  }
}
