import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Central app-level backend configuration.
/// Normal users never see or edit server URLs — the app connects seamlessly
/// in the background.
///
/// For production builds (e.g. free Render.com hosting), either:
/// 1) Replace `_productionBackendUrl` below, OR
/// 2) Pass `--dart-define=BACKEND_URL=https://your-app.onrender.com` when building.
class AppConfig {
  static const String _envBackendUrl =
      String.fromEnvironment('BACKEND_URL', defaultValue: '');

  static const String _envApiSecret =
      String.fromEnvironment('API_SECRET', defaultValue: '');

  /// Set this to your deployed backend URL (e.g. 'https://your-app.onrender.com')
  /// before releasing an APK to real phones. Leave empty for local development.
  static const String _productionBackendUrl =
      'https://remindly-bot-cc713.containers.snapdeploy.app';

  static String get backendUrl {
    if (_envBackendUrl.trim().isNotEmpty) {
      return _stripTrailingSlash(_envBackendUrl);
    }
    if (_productionBackendUrl.trim().isNotEmpty) {
      return _stripTrailingSlash(_productionBackendUrl);
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'http://localhost:3000';
    }
    return 'http://10.0.2.2:3000';
  }

  static String get apiSecret => _envApiSecret.trim();

  static String _stripTrailingSlash(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  /// Best-effort automatic local timezone detection (including Chrome/Web).
  static String detectFallbackTimezone(String deviceTimezone) {
    if (deviceTimezone.isNotEmpty && deviceTimezone != 'UTC') {
      return deviceTimezone;
    }
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    const offsetToIana = <int, String>{
      300: 'Asia/Karachi',
      330: 'Asia/Kolkata',
      240: 'Asia/Dubai',
      180: 'Asia/Riyadh',
      360: 'Asia/Dhaka',
      480: 'Asia/Singapore',
      0: 'Europe/London',
      60: 'Europe/Berlin',
      -300: 'America/New_York',
      -480: 'America/Los_Angeles',
    };
    return offsetToIana[offsetMinutes] ?? 'UTC';
  }
}
