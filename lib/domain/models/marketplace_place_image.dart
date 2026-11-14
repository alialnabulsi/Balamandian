import 'marketplace_json.dart';

class MarketplacePlaceImage {
  const MarketplacePlaceImage({
    required this.id,
    required this.imageUrl,
    required this.alternativeText,
    required this.sortOrder,
  });
  final String id, imageUrl;
  final String? alternativeText;
  final int sortOrder;
  factory MarketplacePlaceImage.fromJson(Object? value) {
    final j = MarketplaceJson.object(value);
    final url = MarketplaceJson.url(j, 'imageUrl');
    if (url == null) throw const FormatException('Missing gallery URL.');
    return MarketplacePlaceImage(
      id: MarketplaceJson.id(j, 'id'),
      imageUrl: url,
      alternativeText: MarketplaceJson.nullableText(j, 'alternativeText'),
      sortOrder: MarketplaceJson.integer(j, 'sortOrder'),
    );
  }
}
