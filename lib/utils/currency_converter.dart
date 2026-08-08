/// Utility class for converting monetary amounts between currencies.
///
/// Uses a base currency (USD) pivot approach: converts source → USD → target.
/// Rates are provided dynamically from the backend via [ExchangeRateService].
/// A static fallback map ensures offline conversions remain functional.
class CurrencyConverter {
  /// Fallback rates (currency → USD) used when no cached rates are available.
  /// These are approximate and will be overridden by live rates from the backend.
  static const Map<String, double> _fallbackRatesToUsd = {
    'USD': 1.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'XAF': 610.0,
    'XOF': 610.0,
    'NGN': 1500.0,
    'JPY': 155.0,
    'GNF': 8600.0,
    'CDF': 2800.0,
    'GHS': 15.0,
    'KES': 130.0,
    'ZAR': 18.0,
    'MAD': 10.0,
    'TND': 3.1,
    'EGP': 48.0,
    'INR': 83.0,
    'CNY': 7.25,
    'BRL': 5.0,
    'CAD': 1.36,
    'AUD': 1.53,
    'CHF': 0.88,
  };

  /// Maps legacy/display currency labels to their ISO 4217 codes.
  /// This handles the case where users have 'CFA', '€', '$', '£' stored
  /// in their profile from the old manual currency picker.
  static const Map<String, String> _aliases = {
    'CFA': 'XAF',
    '€': 'EUR',
    '\$': 'USD',
    '£': 'GBP',
  };

  /// Normalizes a currency code by resolving known aliases to ISO codes.
  static String _normalize(String code) => _aliases[code] ?? code;

  /// Converts [amount] from currency [from] to currency [to].
  ///
  /// [activeRates] should be the map returned by [ExchangeRateService.getRates()].
  /// If a currency is not found in [activeRates], the fallback rate is used.
  /// If neither source is available, a rate of 1.0 is assumed (no conversion).
  static double convert({
    required double amount,
    required String from,
    required String to,
    required Map<String, double> activeRates,
  }) {
    final normFrom = _normalize(from);
    final normTo = _normalize(to);

    if (normFrom == normTo) return amount;

    final rateFrom = activeRates[normFrom] ?? _fallbackRatesToUsd[normFrom];
    final rateTo = activeRates[normTo] ?? _fallbackRatesToUsd[normTo];

    // If we don't know either currency, return the amount unchanged to avoid data loss.
    if (rateFrom == null || rateTo == null) return amount;

    // Cross-rate via USD pivot: amount / rateFrom = USD value, * rateTo = target value.
    return (amount / rateFrom) * rateTo;
  }

  /// Returns the conversion rate from [from] to [to].
  ///
  /// Useful for displaying the rate to the user before confirming a conversion.
  static double getRate({
    required String from,
    required String to,
    required Map<String, double> activeRates,
  }) {
    final normFrom = _normalize(from);
    final normTo = _normalize(to);

    if (normFrom == normTo) return 1.0;

    final rateFrom = activeRates[normFrom] ?? _fallbackRatesToUsd[normFrom];
    final rateTo = activeRates[normTo] ?? _fallbackRatesToUsd[normTo];

    if (rateFrom == null || rateTo == null) return 1.0;

    return rateTo / rateFrom;
  }
}
