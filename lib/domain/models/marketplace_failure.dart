class MarketplaceFailure implements Exception {
  const MarketplaceFailure(this.code, this.message, {this.retryAfter});
  final String code, message;
  final Duration? retryAfter;
  static const invalidResponse = MarketplaceFailure(
    'INVALID_RESPONSE',
    'Marketplace returned an unexpected response. Please try again later.',
  );
  static const network = MarketplaceFailure(
    'NETWORK_ERROR',
    'Cannot reach the marketplace. Check your connection and try again.',
  );
  factory MarketplaceFailure.fromApi(String? code, {Duration? retryAfter}) =>
      MarketplaceFailure(
        const {
              'PLACE_NOT_FOUND',
              'RATE_LIMITED',
              'VALIDATION_ERROR',
            }.contains(code)
            ? code!
            : 'SERVICE_ERROR',
        switch (code) {
          'PLACE_NOT_FOUND' => 'This place is no longer available.',
          'RATE_LIMITED' =>
            'Too many marketplace changes. Please wait before trying again.',
          'VALIDATION_ERROR' => 'Check your marketplace request and try again.',
          _ => 'Marketplace is unavailable. Please try again later.',
        },
        retryAfter: retryAfter,
      );
  @override
  String toString() => 'MarketplaceFailure($code)';
}
