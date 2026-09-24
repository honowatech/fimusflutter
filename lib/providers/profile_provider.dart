import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../utils/countries_data.dart';

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

  /// Réinitialise le profil local (déconnexion) : supprime les données
  /// personnelles du stockage local et revient au profil par défaut.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_profile');
    _profile = UserProfile(firstName: 'Utilisateur', lastName: 'MoniTrack');
    notifyListeners();
  }

  Future<void> updateUserType(String newType) async {
    await updateProfile(_profile.copyWith(type: newType));
  }

  /// Change profile type permanently. This can only be done once.
  Future<bool> changeProfileType(String newType) async {
    if (_profile.hasChangedType) {
      return false; // Action already consumed
    }

    // Determine backend mapped type name if needed, or stick to 'professionnel'/'particulier'
    final updatedProfile = _profile.copyWith(
      type: newType,
      hasChangedType: true,
    );

    await updateProfile(updatedProfile);

    // Attempt to notify backend
    try {
      final authService = AuthService();
      if (await authService.hasToken()) {
        // Here we could call a specific endpoint, but pushing sync is a good fallback
        // if user_profile is handled during sync or we just keep it local for now.
        // The instructions suggest pushing sync.
        await SyncService().push();
        debugPrint('[ProfileProvider] Profile type change synced.');
      }
    } catch (e) {
      debugPrint('[ProfileProvider] Backend sync failed for profile type change: $e');
    }

    return true;
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
      // --- 1. Marquer la devise historique des lignes qui n'en ont pas ---
      //
      // Auparavant, un changement de pays multipliait tous les montants par un
      // taux de change : l'historique était réécrit, et une dépense de
      // 10 000 XOF réellement payée devenait « 15,24 EUR » en base. Depuis le
      // palier 19, chaque ligne porte sa devise de saisie.
      //
      // Les lignes antérieures ont `currency IS NULL`, ce qui signifie « à
      // interpréter dans la devise du profil ». Au moment précis où le profil
      // change de devise, cette convention allait rendre ces lignes fausses :
      // on fige donc leur devise à l'ancienne — c'est exactement ce qu'elles
      // valaient jusqu'ici, aucune donnée n'est inventée. Les montants, eux,
      // ne bougent plus.
      final db = await DatabaseService.instance.database;
      final nowStr = DateTime.now().toIso8601String();
      var lignesMarquees = 0;

      if (oldCurrency != newCurrency) {
        await db.transaction((txn) async {
          for (final table in const ['accounts', 'expenses']) {
            lignesMarquees += await txn.rawUpdate(
              'UPDATE $table SET currency = ?, is_synced = 0, updated_at = ? '
              'WHERE currency IS NULL',
              [oldCurrency, nowStr],
            );
          }
        });
        debugPrint(
            '[CurrencyConversion] Devise historique figée sur $lignesMarquees ligne(s) : $oldCurrency');
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

      // --- 5. Envoi au serveur (best-effort) ---
      if (lignesMarquees > 0) {
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
