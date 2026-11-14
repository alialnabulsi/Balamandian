import 'marketplace_category.dart';
import 'marketplace_json.dart';
import 'marketplace_rating_result.dart';

class MarketplacePlaceSummary {
  const MarketplacePlaceSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.coverImageUrl,
    required this.address,
    required this.category,
    required this.averageRating,
    required this.ratingCount,
    required this.myRating,
    required this.isFavorite,
  });
  final String id, name, slug, description, address;
  final String? coverImageUrl;
  final MarketplaceCategory category;
  final double averageRating;
  final int ratingCount;
  final int? myRating;
  final bool isFavorite;
  factory MarketplacePlaceSummary.fromJson(Object? value) {
    final j = MarketplaceJson.object(value);
    return MarketplacePlaceSummary(
      id: MarketplaceJson.id(j, 'id'),
      name: MarketplaceJson.text(j, 'name'),
      slug: MarketplaceJson.text(j, 'slug'),
      description: MarketplaceJson.text(j, 'description'),
      coverImageUrl: MarketplaceJson.url(j, 'coverImageUrl'),
      address: MarketplaceJson.text(j, 'address'),
      category: MarketplaceCategory.fromJson(
        MarketplaceJson.required(j, 'category'),
        summary: true,
      ),
      averageRating: MarketplaceJson.number(j, 'averageRating'),
      ratingCount: MarketplaceJson.integer(j, 'ratingCount'),
      myRating: MarketplaceJson.rating(j, 'myRating'),
      isFavorite: MarketplaceJson.boolean(j, 'isFavorite'),
    );
  }
  MarketplacePlaceSummary copyWith({
    bool? isFavorite,
    MarketplaceRatingResult? rating,
  }) => MarketplacePlaceSummary(
    id: id,
    name: name,
    slug: slug,
    description: description,
    coverImageUrl: coverImageUrl,
    address: address,
    category: category,
    averageRating: rating?.averageRating ?? averageRating,
    ratingCount: rating?.ratingCount ?? ratingCount,
    myRating: rating == null ? myRating : rating.myRating,
    isFavorite: isFavorite ?? this.isFavorite,
  );
}
