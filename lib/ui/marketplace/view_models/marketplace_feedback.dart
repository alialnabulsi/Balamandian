import '../../../domain/models/auth_failure.dart';
import '../../../domain/models/marketplace_failure.dart';

String marketplaceMessage(Object error) => switch (error) {
  MarketplaceFailure(:final message, :final retryAfter) =>
    retryAfter == null
        ? message
        : '$message Try again in ${retryAfter.inSeconds} seconds.',
  AuthFailure() => 'Your session changed. Please log in again.',
  _ => 'Marketplace is unavailable. Please try again later.',
};
