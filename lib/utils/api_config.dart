import '../config/app_environment.dart';

export '../config/app_environment.dart';

class ApiConfig {
  static const String prodBaseUrl = AppEnvironment.prodBaseUrl;

  // Production par défaut : l'environnement est résolu au démarrage par
  // EnvironmentStore puis modifié uniquement via AppConfigProvider.
  static AppEnvironment _env = AppEnvironment.production;

  /// Environnement actif (URL de l'API, clés de stockage, noms de bases)
  static AppEnvironment get env => _env;

  /// Indique si l'application est en production
  static bool get isProduction => !_env.isDev;

  /// Indique si l'application est en mode développement (BD / API locale)
  static bool get isDevMode => _env.isDev;

  static void configure(AppEnvironment env) => _env = env;

  /// Retourne l'URL de base active
  static String get baseUrl => _env.apiBaseUrl;

  // Auth Endpoints
  static String get login          => '$baseUrl/login';
  static String get register       => '$baseUrl/register';
  static String get forgotPassword => '$baseUrl/forgot-password';
  static String get logout         => '$baseUrl/logout';
  static String get user           => '$baseUrl/user';
  static String get updatePseudo   => '$baseUrl/user/update-pseudo';
  static String get googleAuth     => '$baseUrl/auth/google';

  /// Réglages applicatifs publics (limite multicompte par appareil, etc.)
  static String get appSettings    => '$baseUrl/app-settings';

  // Reference Data Endpoints
  static String get countries      => '$baseUrl/countries';
  static String get operators      => '$baseUrl/operators';
  static String get ussdCodes      => '$baseUrl/ussd-codes';
  static String get ussdByCountry  => '$baseUrl/ussd-by-country';

  // Sync Endpoints
  static String get syncPull       => '$baseUrl/sync/pull';
  static String get syncPush       => '$baseUrl/sync/push';

  // Exchange Rates
  static String get exchangeRates  => '$baseUrl/exchange-rates';

  // User Country Update
  static String get updateCountry  => '$baseUrl/user/update-country';

  // Announcements
  static String get announcements  => '$baseUrl/announcements';

  static String get storageUrl     => baseUrl.replaceAll('/api', '/storage');

  static const _localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

  /// En dev, les URLs produites par Laravel (`asset()`) pointent vers un hôte
  /// local (localhost, 127.0.0.1:8000…) : on les redirige vers l'origine de
  /// l'API active, joignable depuis l'appareil.
  static String mapImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (isProduction) return url;

    final uri = Uri.tryParse(url);
    if (uri == null || !_localHosts.contains(uri.host)) return url;

    final api = Uri.parse(baseUrl);
    return Uri(
      scheme: api.scheme,
      host: api.host,
      port: api.hasPort ? api.port : null,
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
    ).toString();
  }
}
