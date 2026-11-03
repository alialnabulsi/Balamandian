import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Coordinates presentation only; no startup policy or persistent state.
abstract final class NativeSplashHandoff {
  static const _channel = MethodChannel('balamandian/splash');

  /// The native icon bounds in Flutter-view logical coordinates, if available.
  static Future<Rect?> prepare() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final bounds = await _channel.invokeListMethod<num>('prepare');
      if (bounds == null) return null;
      return Rect.fromLTWH(
        bounds[0].toDouble(),
        bounds[1].toDouble(),
        bounds[2].toDouble(),
        bounds[3].toDouble(),
      );
    } on MissingPluginException {
      return null; // Widget previews and non-Android hosts have no native overlay.
    } on PlatformException {
      return null; // Activity teardown; the view checks mounted before continuing.
    }
  }

  /// Completes after Android removes its overlay and crosses a display frame.
  static Future<void> reveal() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('reveal');
    } on MissingPluginException {
      // No overlay on this host.
    } on PlatformException {
      // Activity teardown.
    }
  }
}
