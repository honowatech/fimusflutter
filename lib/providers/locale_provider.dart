import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/notifications/notification_texts.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';

class LocaleProvider with ChangeNotifier {
  Locale _locale = const Locale('fr'); // Default to French

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? languageCode = prefs.getString('language_code');
    if (languageCode != null) {
      _locale = Locale(languageCode);
      NotificationTexts.setLocale(_locale);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!['en', 'fr'].contains(locale.languageCode)) return;
    
    _locale = locale;
    NotificationTexts.setLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
    notifyListeners();

    try {
      final token = await AuthService().getToken();
      if (token != null) {
        await ApiClient.instance.post(
          '${ApiConfig.baseUrl}/users/locale',
          data: {'locale': locale.languageCode},
        );
      }
    } catch (e) {
      debugPrint('Failed to sync locale to backend: $e');
    }
  }
}
