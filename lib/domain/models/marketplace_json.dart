// Feature-local runtime validation. Invalid wire data never becomes renderable state.
abstract final class MarketplaceJson {
  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid marketplace object.');
    }
    return value;
  }

  static Object? required(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) {
      throw const FormatException('Missing marketplace field.');
    }
    return json[key];
  }

  static String text(Map<String, dynamic> json, String key) {
    final value = required(json, key);
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Invalid marketplace text.');
    }
    return value;
  }

  static String id(Map<String, dynamic> json, String key) {
    final value = text(json, key);
    if (!RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
        .hasMatch(value)) {
      throw const FormatException('Invalid marketplace id.');
    }
    return value;
  }

  static String? nullableText(Map<String, dynamic> json, String key) =>
      required(json, key) == null ? null : text(json, key);
  static String? url(Map<String, dynamic> json, String key) {
    final value = nullableText(json, key);
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid external URL.');
    }
    return value;
  }

  static int integer(
    Map<String, dynamic> json,
    String key, {
    int min = 0,
    int? max,
  }) {
    final value = required(json, key);
    if (value is! int || value < min || (max != null && value > max)) {
      throw const FormatException('Invalid marketplace integer.');
    }
    return value;
  }

  static int? rating(Map<String, dynamic> json, String key) =>
      required(json, key) == null ? null : integer(json, key, min: 1, max: 5);
  static double number(
    Map<String, dynamic> json,
    String key, {
    double min = 0,
    double max = 5,
  }) {
    final value = required(json, key);
    if (value is! num || !value.isFinite || value < min || value > max) {
      throw const FormatException('Invalid marketplace number.');
    }
    return value.toDouble();
  }

  static double? coordinate(
    Map<String, dynamic> json,
    String key,
    double bound,
  ) => required(json, key) == null
      ? null
      : number(json, key, min: -bound, max: bound);
  static bool boolean(Map<String, dynamic> json, String key) {
    final value = required(json, key);
    if (value is! bool) {
      throw const FormatException('Invalid marketplace boolean.');
    }
    return value;
  }

  static DateTime date(Map<String, dynamic> json, String key) {
    final textValue = text(json, key);
    final value = DateTime.tryParse(textValue);
    if (value == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(textValue)) {
      throw const FormatException('Invalid marketplace date.');
    }
    return value.toUtc();
  }

  static List<T> list<T>(Object? value, T Function(Object?) parse) {
    if (value is! List) {
      throw const FormatException('Invalid marketplace list.');
    }
    return List.unmodifiable(value.map(parse));
  }
}
