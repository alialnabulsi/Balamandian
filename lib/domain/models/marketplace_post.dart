import 'marketplace_json.dart';

class MarketplacePostPlace {
  const MarketplacePostPlace({
    required this.id,
    required this.name,
    required this.slug,
    required this.coverImageUrl,
  });
  final String id, name, slug;
  final String? coverImageUrl;
  factory MarketplacePostPlace.fromJson(Object? value) {
    final j = MarketplaceJson.object(value);
    return MarketplacePostPlace(
      id: MarketplaceJson.id(j, 'id'),
      name: MarketplaceJson.text(j, 'name'),
      slug: MarketplaceJson.text(j, 'slug'),
      coverImageUrl: MarketplaceJson.url(j, 'coverImageUrl'),
    );
  }
}

class MarketplacePost {
  const MarketplacePost({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.startsAt,
    required this.endsAt,
    required this.isFavoritePlace,
    required this.place,
  });
  final String id, type, title, body;
  final String? imageUrl;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool isFavoritePlace;
  final MarketplacePostPlace place;
  factory MarketplacePost.fromJson(Object? value) {
    final j = MarketplaceJson.object(value);
    final type = MarketplaceJson.text(j, 'type');
    if (type != 'news' && type != 'advertisement') {
      throw const FormatException('Invalid post type.');
    }
    final starts = MarketplaceJson.date(j, 'startsAt');
    final ends = MarketplaceJson.required(j, 'endsAt') == null
        ? null
        : MarketplaceJson.date(j, 'endsAt');
    if (ends != null && !ends.isAfter(starts)) {
      throw const FormatException('Invalid post schedule.');
    }
    return MarketplacePost(
      id: MarketplaceJson.id(j, 'id'),
      type: type,
      title: MarketplaceJson.text(j, 'title'),
      body: MarketplaceJson.text(j, 'body'),
      imageUrl: MarketplaceJson.url(j, 'imageUrl'),
      startsAt: starts,
      endsAt: ends,
      isFavoritePlace: MarketplaceJson.boolean(j, 'isFavoritePlace'),
      place: MarketplacePostPlace.fromJson(
        MarketplaceJson.required(j, 'place'),
      ),
    );
  }
}
