import 'package:url_launcher/url_launcher.dart';

abstract class ExternalUrlService {
  Future<bool> launch(Uri uri);
}

class PlatformExternalUrlService implements ExternalUrlService {
  const PlatformExternalUrlService();
  @override
  Future<bool> launch(Uri uri) async {
    if (!((uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty) ||
        uri.scheme == 'tel')) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
