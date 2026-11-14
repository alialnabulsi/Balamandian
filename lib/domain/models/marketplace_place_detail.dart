import 'marketplace_json.dart';
import 'marketplace_place_summary.dart';
import 'marketplace_place_image.dart';
import 'marketplace_opening_hour.dart';
import 'marketplace_rating_result.dart';

class MarketplacePlaceDetail {
  MarketplacePlaceDetail({
    required this.place,
    required this.latitude,
    required this.longitude,
    required this.googleMapsUrl,
    required this.phoneNumber,
    required this.websiteUrl,
    required this.socialUrl,
    required this.timezone,
    required List<MarketplacePlaceImage> images,
    required List<MarketplaceOpeningHour> openingHours,
  }) : images = List.unmodifiable(images),
       openingHours = List.unmodifiable(openingHours);
  final MarketplacePlaceSummary place;
  final double? latitude, longitude;
  final String? googleMapsUrl, phoneNumber, websiteUrl, socialUrl;
  final String timezone;
  final List<MarketplacePlaceImage> images;
  final List<MarketplaceOpeningHour> openingHours;
  factory MarketplacePlaceDetail.fromJson(Object? value) {
    final j = MarketplaceJson.object(value);
    final lat = MarketplaceJson.coordinate(j, 'latitude', 90),
        lng = MarketplaceJson.coordinate(j, 'longitude', 180);
    if ((lat == null) != (lng == null)) {
      throw const FormatException('Invalid coordinate pair.');
    }
    return MarketplacePlaceDetail(
      place: MarketplacePlaceSummary.fromJson(j),
      latitude: lat,
      longitude: lng,
      googleMapsUrl: MarketplaceJson.url(j, 'googleMapsUrl'),
      phoneNumber: MarketplaceJson.nullableText(j, 'phoneNumber'),
      websiteUrl: MarketplaceJson.url(j, 'websiteUrl'),
      socialUrl: MarketplaceJson.url(j, 'socialUrl'),
      timezone: MarketplaceJson.text(j, 'timezone'),
      images: MarketplaceJson.list(
        MarketplaceJson.required(j, 'images'),
        MarketplacePlaceImage.fromJson,
      ),
      openingHours: MarketplaceJson.list(
        MarketplaceJson.required(j, 'openingHours'),
        MarketplaceOpeningHour.fromJson,
      ),
    );
  }
  MarketplacePlaceDetail copyWith({
    bool? isFavorite,
    MarketplaceRatingResult? rating,
  }) => MarketplacePlaceDetail(
    place: place.copyWith(isFavorite: isFavorite, rating: rating),
    latitude: latitude,
    longitude: longitude,
    googleMapsUrl: googleMapsUrl,
    phoneNumber: phoneNumber,
    websiteUrl: websiteUrl,
    socialUrl: socialUrl,
    timezone: timezone,
    images: images,
    openingHours: openingHours,
  );
}
