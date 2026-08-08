import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';

/// Service responsible for fetching, caching, and providing exchange rates.
///
/// Rates are stored in SharedPreferences as a JSON map of currency code → rate
/// relative to USD (e.g. {"EUR": 0.92, "XAF": 610.0, ...}).
///
/// The backend endpoint GET /exchange-rates returns the same format.
class ExchangeRateService {
  static const String _cacheKey = 'cached_exchange_rates';
  static const String _cacheTimestampKey = 'exchange_rates_timestamp';

  final Dio _dio = Dio();

  ExchangeRateService() {
    _dio.options.headers['Accept'] = 'application/json';
  }

  /// Fetches rates from the backend and caches them locally.
  ///
  /// This should be called during sync or at app startup.
  /// Failures are silently ignored — the app will fall back to
  /// previously cached rates or static defaults.
  Future<void> syncRates() async {
    try {
      final response = await _dio.get('${ApiConfig.baseUrl}/exchange-rates');
      if (response.statusCode == 200 && response.data is Map) {
        final Map<String, dynamic> rawRates = response.data;
        final Map<String, double> rates = rawRates.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
        await _cacheRates(rates);
      }
    } catch (_) {
      // Silent failure — cached or fallback rates will be used.
    }
  }

  /// Returns the currently cached exchange rates.
  ///
  /// Returns an empty map if no rates have been cached yet,
  /// which signals [CurrencyConverter] to use its fallback rates.
  Future<Map<String, double>> getRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_cacheKey);
      if (jsonStr != null) {
        final Map<String, dynamic> decoded = json.decode(jsonStr);
        return decoded.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
      }
    } catch (_) {
      // Fall through to empty map.
    }
    return {};
  }

  /// Returns the timestamp of the last successful rate sync, or null.
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final int? millis = prefs.getInt(_cacheTimestampKey);
    if (millis != null) {
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return null;
  }

  /// Persists [rates] to SharedPreferences with the current timestamp.
  Future<void> _cacheRates(Map<String, double> rates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, json.encode(rates));
    await prefs.setInt(
      _cacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
