class AppEnv {
  AppEnv._();

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _envGoogleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String _defaultBaseUrl = 'https://api.iway.one/api';

  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _normalize(_envBaseUrl);
    }

    return _defaultBaseUrl;
  }

  static String get fallbackApiBaseUrl => _defaultBaseUrl;

  static String get googleMapsApiKey => _envGoogleMapsApiKey.trim();

  static String _normalize(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'/$'), '');
    return trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
  }
}
