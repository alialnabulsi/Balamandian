import 'marketplace_json.dart';

class MarketplaceOpeningHour {
  const MarketplaceOpeningHour({
    required this.dayOfWeek,
    required this.opensAt,
    required this.closesAt,
  });
  final int dayOfWeek;
  final String opensAt, closesAt;
  bool get crossesMidnight => closesAt.compareTo(opensAt) < 0;
  factory MarketplaceOpeningHour.fromJson(Object? value) {
    final j = MarketplaceJson.object(value);
    final opens = MarketplaceJson.text(j, 'opensAt'),
        closes = MarketplaceJson.text(j, 'closesAt');
    final valid = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (!valid.hasMatch(opens) || !valid.hasMatch(closes) || opens == closes) {
      throw const FormatException('Invalid opening interval.');
    }
    return MarketplaceOpeningHour(
      dayOfWeek: MarketplaceJson.integer(j, 'dayOfWeek', min: 1, max: 7),
      opensAt: opens,
      closesAt: closes,
    );
  }
}
