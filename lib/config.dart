class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://water-system-h5zu.onrender.com/api',
  );
  static const Duration requestTimeout = Duration(seconds: 25);
}
