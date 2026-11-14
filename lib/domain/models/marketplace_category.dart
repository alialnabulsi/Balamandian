import 'marketplace_json.dart';

class MarketplaceCategory {
  const MarketplaceCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconKey,
    this.sortOrder,
  });
  final String id, name, slug, iconKey;
  final int? sortOrder;
  factory MarketplaceCategory.fromJson(Object? value, {bool summary = false}) {
    final j = MarketplaceJson.object(value);
    return MarketplaceCategory(
      id: MarketplaceJson.id(j, 'id'),
      name: MarketplaceJson.text(j, 'name'),
      slug: MarketplaceJson.text(j, 'slug'),
      iconKey: MarketplaceJson.text(j, 'iconKey'),
      sortOrder: summary ? null : MarketplaceJson.integer(j, 'sortOrder'),
    );
  }
}
