import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static const bool isProduction = true;
  static const String prodBaseUrl = 'https://fimus.honowa.com/api'; // Remplacez par votre domaine en prod

  /// Returns the correct base URL depending on the runtime environment:
  /// - Browser (Flutter Web) → http://localhost:8000/api
  /// - Android emulator      → http://10.0.2.2:8000/api  (emulator maps 10.0.2.2 → host machine)
  /// - Physical device / iOS → replace with your machine's LAN IP (e.g. http://192.168.1.x:8000/api)
  static String get baseUrl {
    if (isProduction) {
      if (!prodBaseUrl.startsWith('https://')) {
         throw Exception("Production API URL must use HTTPS.");
      }
      return prodBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }
    // Android emulator: 10.0.2.2 maps to the host machine's localhost
    return 'http://10.0.2.2:8000/api';
  }

  // Auth Endpoints
  static String get login    => '$baseUrl/login';
  static String get register => '$baseUrl/register';
  static String get logout   => '$baseUrl/logout';
  static String get user     => '$baseUrl/user';

  // Reference Data Endpoints
  static String get countries => '$baseUrl/countries';
  static String get operators => '$baseUrl/operators';
  static String get ussdCodes => '$baseUrl/ussd-codes';
  static String get ussdByCountry => '$baseUrl/ussd-by-country';

  // Sync Endpoints
  static String get syncPull => '$baseUrl/sync/pull';
  static String get syncPush => '$baseUrl/sync/push';

  // Announcements
  static String get announcements => '$baseUrl/announcements';

  static String get storageUrl => baseUrl.replaceAll('/api', '/storage');

  /// Remplace l'IP localhost par la bonne adresse selon l'environnement
  static String mapImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    if (isProduction) return url;

    String mappedUrl = url;
    // Fix missing port 8000 for local development URLs returned by Laravel asset() without port
    if (mappedUrl.startsWith('http://localhost/')) {
      mappedUrl = mappedUrl.replaceFirst('http://localhost/', 'http://localhost:8000/');
    } else if (mappedUrl.startsWith('http://127.0.0.1/')) {
      mappedUrl = mappedUrl.replaceFirst('http://127.0.0.1/', 'http://127.0.0.1:8000/');
    }

    if (kIsWeb) {
      // Dans le navigateur, localhost est déjà correct
      return mappedUrl.replaceAll('10.0.2.2', 'localhost').replaceAll('127.0.0.1', 'localhost');
    }
    return mappedUrl.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
  }
}

