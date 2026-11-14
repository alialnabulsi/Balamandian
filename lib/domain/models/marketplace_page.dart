import 'marketplace_json.dart';

class MarketplacePagination {
  const MarketplacePagination({
    required this.page,
    required this.limit,
    required this.totalItems,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });
  final int page, limit, totalItems, totalPages;
  final bool hasNextPage, hasPreviousPage;
  factory MarketplacePagination.fromJson(Object? value) {
    final j = MarketplaceJson.object(value);
    final page = MarketplaceJson.integer(j, 'page', min: 1),
        limit = MarketplaceJson.integer(j, 'limit', min: 1, max: 50),
        total = MarketplaceJson.integer(j, 'totalItems'),
        pages = MarketplaceJson.integer(j, 'totalPages');
    final next = MarketplaceJson.boolean(j, 'hasNextPage'),
        previous = MarketplaceJson.boolean(j, 'hasPreviousPage');
    if (pages != (total / limit).ceil() ||
        next != (page < pages) ||
        previous != (page > 1)) {
      throw const FormatException('Inconsistent marketplace pagination.');
    }
    return MarketplacePagination(
      page: page,
      limit: limit,
      totalItems: total,
      totalPages: pages,
      hasNextPage: next,
      hasPreviousPage: previous,
    );
  }
}

class MarketplacePage<T> {
  MarketplacePage({required List<T> items, required this.pagination})
    : items = List.unmodifiable(items);
  final List<T> items;
  final MarketplacePagination pagination;
  factory MarketplacePage.fromJson(Object? value, T Function(Object?) parse) {
    final j = MarketplaceJson.object(value);
    final pagination = MarketplacePagination.fromJson(
      MarketplaceJson.required(j, 'pagination'),
    );
    final items = MarketplaceJson.list(
      MarketplaceJson.required(j, 'items'),
      parse,
    );
    if (items.length > pagination.limit ||
        (pagination.totalItems == 0 && items.isNotEmpty)) {
      throw const FormatException('Inconsistent marketplace page.');
    }
    return MarketplacePage(items: items, pagination: pagination);
  }
}
