import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_preferences.dart';
import '../utils/api_config.dart';
import 'package:http/http.dart' as http;

class NotificationPreferencesProvider extends ChangeNotifier {
  NotificationPreferences? _preferences;
  bool _isLoading = false;

  NotificationPreferences? get preferences => _preferences;
  bool get isLoading => _isLoading;

  Future<void> fetchPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/notification-preferences'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _preferences = NotificationPreferences.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching notification preferences: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreferences(NotificationPreferences newPrefs) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    _preferences = newPrefs;
    notifyListeners(); // Optimistic update

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/users/notification-preferences'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(newPrefs.toJson()),
      );

      if (response.statusCode == 200) {
        _preferences = NotificationPreferences.fromJson(jsonDecode(response.body));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
      // Revert on error could be implemented here
    }
  }
}
