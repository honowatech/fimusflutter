import 'package:flutter/foundation.dart';

/// Hôte du serveur Laravel local utilisé en mode dev.
enum DevHost {
  vhost('http://fimus.local/api'),
  emulator('http://10.0.2.2/api'),
  web('http://localhost/api'),
  custom(null);

  const DevHost(this.defaultUrl);

  /// URL fixe de l'hôte ; `null` pour [custom] (URL saisie par le développeur).
  final String? defaultUrl;

  static DevHost? tryParse(String? name) {
    for (final host in values) {
      if (host.name == name) return host;
    }
    return null;
  }
}

/// Environnement d'exécution (production ou serveur local) : source de vérité
/// unique pour l'URL de l'API, les clés de stockage et les noms de bases.
/// Immuable : un changement d'environnement produit une nouvelle instance.
@immutable
class AppEnvironment {
  static const String prodBaseUrl = 'https://fimus.honowa.com/api';
  static const String defaultCustomUrl = 'http://fimus.local/api';

  static const production = AppEnvironment._(
    isDev: false,
    host: DevHost.vhost,
    customUrl: defaultCustomUrl,
  );

  const AppEnvironment._({
    required this.isDev,
    required this.host,
    required this.customUrl,
  });

  factory AppEnvironment.local({
    DevHost host = DevHost.vhost,
    String? customUrl,
  }) =>
      AppEnvironment._(
        isDev: true,
        host: host,
        customUrl: normalizeUrl(customUrl ?? defaultCustomUrl),
      );

  final bool isDev;
  final DevHost host;

  /// URL saisie pour [DevHost.custom], conservée même quand un autre hôte
  /// est sélectionné afin de la retrouver en revenant sur « personnalisée ».
  final String customUrl;

  AppEnvironment copyWith({bool? isDev, DevHost? host, String? customUrl}) =>
      AppEnvironment._(
        isDev: isDev ?? this.isDev,
        host: host ?? this.host,
        customUrl:
            customUrl != null ? normalizeUrl(customUrl) : this.customUrl,
      );

  String get apiBaseUrl {
    if (!isDev) {
      assert(prodBaseUrl.startsWith('https://'),
          'Production API URL must use HTTPS.');
      return prodBaseUrl;
    }
    return host.defaultUrl ?? normalizeUrl(customUrl);
  }

  /// Clé de stockage propre à l'environnement : `auth_token` en production,
  /// `auth_token_dev` en dev (noms historiques conservés, aucune migration).
  String scoped(String key) => isDev ? '${key}_dev' : key;

  /// Préfixe des bases SQLite par compte.
  String get dbPrefix => isDev ? 'monitrack_dev_' : 'monitrack_';

  /// Base partagée historique (sans session active).
  String get sharedDbName => isDev ? 'monitrack_dev.db' : 'monitrack.db';

  /// Identité stable : un changement d'identité redémarre l'arbre applicatif.
  String get id => isDev ? 'dev|$apiBaseUrl' : 'prod';

  /// `fimus.local` → `http://fimus.local/api`, `http://1.2.3.4:8000/` →
  /// `http://1.2.3.4:8000/api`.
  static String normalizeUrl(String raw) {
    var url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/api')) {
      url = '$url/api';
    }
    return url;
  }

  @override
  bool operator ==(Object other) =>
      other is AppEnvironment &&
      other.isDev == isDev &&
      other.host == host &&
      other.customUrl == customUrl;

  @override
  int get hashCode => Object.hash(isDev, host, customUrl);

  @override
  String toString() => 'AppEnvironment($id)';
}
