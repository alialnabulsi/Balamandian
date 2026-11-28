import 'guide_article_ref.dart';

enum GuideLocale { en, ar }

final class GuideSection {
  const GuideSection({
    required this.id,
    required this.slug,
    required this.label,
    required this.hasChildren,
  });
  final String id, slug, label;
  final bool hasChildren;
  factory GuideSection.fromJson(Object? value) {
    final j = _object(value);
    return GuideSection(
      id: _string(j, 'sectionId'),
      slug: _string(j, 'slug'),
      label: _string(j, 'label'),
      hasChildren: j['hasChildren'] as bool,
    );
  }
}

final class GuideArticleSummary {
  const GuideArticleSummary({
    required this.ref,
    required this.slug,
    required this.sectionId,
    required this.summary,
    required this.locale,
    required this.tags,
    required this.verifiedOn,
    this.excerpt,
  });
  final GuideArticleRef ref;
  String get id => ref.articleId;
  String get title => ref.title;
  int get version => ref.version;
  final String slug, sectionId, summary, verifiedOn;
  final GuideLocale locale;
  final List<String> tags;
  final String? excerpt;
  factory GuideArticleSummary.fromJson(Object? value) {
    final j = _object(value);
    final version = j['version'];
    if (version is! int || version < 1) {
      throw const FormatException('Guide version');
    }
    return GuideArticleSummary(
      ref: GuideArticleRef(
        articleId: _string(j, 'articleId'),
        version: version,
        title: _string(j, 'title'),
      ),
      slug: _string(j, 'slug'),
      sectionId: _string(j, 'sectionId'),
      summary: _string(j, 'summary'),
      locale: GuideLocale.values.byName(_string(j, 'locale')),
      tags: List.unmodifiable((j['tags'] as List).cast<String>()),
      verifiedOn: _string(j, 'verifiedOn'),
      excerpt: j['excerpt'] as String?,
    );
  }
}

final class GuideSource {
  const GuideSource({
    required this.key,
    required this.url,
    required this.label,
    this.locator,
  });
  final String key, url, label;
  final String? locator;
  factory GuideSource.fromJson(Object? value) {
    final j = _object(value);
    return GuideSource(
      key: _string(j, 'key'),
      url: _string(j, 'url'),
      label: _string(j, 'label'),
      locator: j['locator'] as String?,
    );
  }
}

final class GuideArticle {
  const GuideArticle({
    required this.summary,
    required this.markdown,
    required this.sources,
    this.academicYear,
    this.validFrom,
    this.validUntil,
  });
  final GuideArticleSummary summary;
  final String markdown;
  final List<GuideSource> sources;
  final String? academicYear;
  final DateTime? validFrom, validUntil;
  factory GuideArticle.fromJson(Object? value) {
    final j = _object(value);
    return GuideArticle(
      summary: GuideArticleSummary.fromJson(j),
      markdown: _string(j, 'markdown'),
      sources: List.unmodifiable(
        (j['sources'] as List).map(GuideSource.fromJson),
      ),
      academicYear: j['academicYear'] as String?,
      validFrom: _date(j['validFrom']),
      validUntil: _date(j['validUntil']),
    );
  }
}

final class GuidePage {
  const GuidePage({required this.items, this.nextCursor});
  final List<GuideArticleSummary> items;
  final String? nextCursor;
  factory GuidePage.fromJson(Object? value) {
    final j = _object(value);
    final items = List<GuideArticleSummary>.unmodifiable(
      (j['items'] as List).map(GuideArticleSummary.fromJson),
    );
    final cursor = j['nextCursor'] as String?;
    if (items.length > 50 ||
        (cursor != null &&
            (cursor.isEmpty || cursor.length > 2048 || items.isEmpty))) {
      throw const FormatException('Guide page');
    }
    return GuidePage(items: items, nextCursor: cursor);
  }
}

final class GuideSectionDetail {
  const GuideSectionDetail({
    required this.section,
    required this.breadcrumb,
    required this.subsections,
    required this.articles,
  });
  final GuideSection section;
  final List<GuideSection> breadcrumb, subsections;
  final GuidePage articles;
  factory GuideSectionDetail.fromJson(Object? value) {
    final j = _object(value);
    return GuideSectionDetail(
      section: GuideSection.fromJson(j['section']),
      breadcrumb: List.unmodifiable(
        (j['breadcrumb'] as List).map(GuideSection.fromJson),
      ),
      subsections: List.unmodifiable(
        (j['subsections'] as List).map(GuideSection.fromJson),
      ),
      articles: GuidePage.fromJson(j['articles']),
    );
  }
}

final class GuideFailure implements Exception {
  const GuideFailure(this.code, this.message);
  final String code, message;
  bool get unavailable =>
      code == 'ARTICLE_NOT_FOUND' || code == 'SECTION_NOT_FOUND';
  static const canceled = GuideFailure(
    'CANCELED',
    'Your session changed. Please try again.',
  );
  static const network = GuideFailure(
    'NETWORK',
    'Unable to reach the University Guide. Check your connection and retry.',
  );
  static const invalidResponse = GuideFailure(
    'INVALID_RESPONSE',
    'The Guide response could not be read. Please retry.',
  );
  factory GuideFailure.fromCode(String? code) => switch (code) {
    'ARTICLE_NOT_FOUND' => const GuideFailure(
      'ARTICLE_NOT_FOUND',
      'This article is currently unavailable.',
    ),
    'SECTION_NOT_FOUND' => const GuideFailure(
      'SECTION_NOT_FOUND',
      'This section is currently unavailable.',
    ),
    'INVALID_REQUEST' => const GuideFailure(
      'INVALID_REQUEST',
      'This request is no longer valid. Reload the list or check your search.',
    ),
    _ => const GuideFailure(
      'SERVICE_ERROR',
      'The University Guide is temporarily unavailable. Please retry.',
    ),
  };
  @override
  String toString() => 'GuideFailure($code)';
}

Map<String, Object?> _object(Object? value) => value as Map<String, Object?>;
String _string(Map<String, Object?> j, String key) => j[key] as String;
DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();
