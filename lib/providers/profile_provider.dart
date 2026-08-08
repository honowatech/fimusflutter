import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/sync_service.dart';
import '../utils/countries_data.dart';
import '../utils/currency_converter.dart';

class ProfileProvider with ChangeNotifier {
  UserProfile _profile = UserProfile(firstName: 'Utilisateur', lastName: 'MoniTrack');

  bool _isConverting = false;

  UserProfile get profile => _profile;
  bool get isConverting => _isConverting;

  ProfileProvider() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profileJson = prefs.getString('user_profile');
    if (profileJson != null) {
      _profile = UserProfile.fromJson(json.decode(profileJson));
      notifyListeners();
    }
  }

  Future<void> updateProfile(UserProfile newProfile) async {
    _profile = newProfile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', json.encode(_profile.toJson()));
    notifyListeners();
  }

  Future<void> updateUserType(String newType) async {
    await updateProfile(_profile.copyWith(type: newType));
  }

  /// Resolves the currency code for a given country name using [CountriesData].
  ///
  /// Returns the ISO currency code (e.g. 'XAF', 'EUR') or 'XAF' as default.
  String currencyForCountry(String countryName) {
    for (final c in CountriesData.countries) {
      if (c['name'] == countryName) {
        final code = c['currency'];
        if (code != null && code.isNotEmpty) return code;
        break;
      }
    }
    return 'XAF';
  }

  /// Changes the user's country, determines the new currency, converts all
  /// local monetary data (account balances, expense amounts), updates the
  /// profile, and notifies the backend.
  ///
  /// This is the single entry point for country changes from the UI.
  Future<void> changeCountryAndConvert(String newCountryName) async {
    final oldCurrency = _profile.currency;
    final newCurrency = currencyForCountry(newCountryName);

    debugPrint('[CurrencyConversion] Country change: ${_profile.country} → $newCountryName');
    debugPrint('[CurrencyConversion] Currency change: $oldCurrency → $newCurrency');

    // If country and currency are identical, just update the country name.
    if (oldCurrency == newCurrency && _profile.country == newCountryName) {
      debugPrint('[CurrencyConversion] No change needed — same country and currency.');
      return;
    }

    _isConverting = true;
    notifyListeners();

    try {
      // --- 1. Compute conversion rate ---
      double conversionRate = 1.0;
      if (oldCurrency != newCurrency) {
        final exchangeRates = await ExchangeRateService().getRates();
        debugPrint('[CurrencyConversion] Cached exchange rates available: ${exchangeRates.length} entries');
        conversionRate = CurrencyConverter.getRate(
          from: oldCurrency,
          to: newCurrency,
          activeRates: exchangeRates,
        );
        debugPrint('[CurrencyConversion] Conversion rate ($oldCurrency → $newCurrency): $conversionRate');
      }

      // --- 2. Convert local SQLite data ---
      if (conversionRate != 1.0) {
        final db = await DatabaseService.instance.database;
        final nowStr = DateTime.now().toIso8601String();

        await db.transaction((txn) async {
          // Convert account balances
          final accountsUpdated = await txn.rawUpdate(
            'UPDATE accounts SET balance = balance * ?, is_synced = 0, updated_at = ?',
            [conversionRate, nowStr],
          );
          debugPrint('[CurrencyConversion] Accounts updated: $accountsUpdated rows');

          // Convert expense amounts and installment amounts
          final expensesUpdated = await txn.rawUpdate(
            'UPDATE expenses SET amount = amount * ?, '
            'installmentAmount = CASE WHEN installmentAmount IS NOT NULL THEN installmentAmount * ? ELSE NULL END, '
            'is_synced = 0, updated_at = ?',
            [conversionRate, conversionRate, nowStr],
          );
          debugPrint('[CurrencyConversion] Expenses updated: $expensesUpdated rows');
        });
      } else {
        debugPrint('[CurrencyConversion] Rate is 1.0 — skipping database conversion.');
      }

      // --- 3. Update profile locally ---
      await updateProfile(_profile.copyWith(
        country: newCountryName,
        currency: newCurrency,
      ));
      debugPrint('[CurrencyConversion] Profile updated: country=$newCountryName, currency=$newCurrency');

      // --- 4. Notify backend of country change (best-effort) ---
      try {
        final authService = AuthService();
        final hasToken = await authService.hasToken();
        if (hasToken) {
          final countries = await authService.getCountries();
          dynamic backendCountry;
          for (final c in countries) {
            if (c['name'] == newCountryName) {
              backendCountry = c;
              break;
            }
          }
          if (backendCountry != null) {
            await authService.updateCountry(backendCountry['id']);
            debugPrint('[CurrencyConversion] Backend country updated (id=${backendCountry['id']})');
          }
        }
      } catch (e) {
        debugPrint('[CurrencyConversion] Backend country update failed: $e');
      }

      // --- 5. Push converted data to backend (best-effort) ---
      if (conversionRate != 1.0) {
        try {
          await SyncService().push();
          debugPrint('[CurrencyConversion] Sync push completed.');
        } catch (e) {
          debugPrint('[CurrencyConversion] Sync push failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[CurrencyConversion] ERROR: $e');
    } finally {
      _isConverting = false;
      notifyListeners();
    }
  }
}
