import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Bidi;

final _letter = RegExp(r'\p{L}', unicode: true);
final _arabic = RegExp(r'^\p{Script=Arabic}$', unicode: true);

TextDirection aiTextDirection(
  String text, [
  TextDirection fallback = TextDirection.ltr,
]) {
  final first = _letter.firstMatch(text)?[0];
  if (first == null) return fallback;
  return _arabic.hasMatch(first) || Bidi.startsWithRtl(first)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

String aiLocale(String question, Locale appLocale) =>
    aiTextDirection(
          question,
          appLocale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
        ) ==
        TextDirection.rtl
    ? 'ar'
    : 'en';
