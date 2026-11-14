abstract final class MarketplaceTokens {
  static const gutter = 16.0;
  static const radius = 8.0;
  static const maxWidth = 720.0;
  static const imageAspect = 1.8;
  static const imageRoot = 'assets/marketplace/images';
  static String placeholder(String slug) =>
      '$imageRoot/${switch (slug) {
        'the-olive-coffee-house' => 'coffee.jpg',
        'the-garden-table' => 'food.jpg',
        'paper-and-ink' => 'books.jpg',
        _ => 'generic.svg',
      }}';
}
