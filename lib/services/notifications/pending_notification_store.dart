import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistance des taps / actions de notification (cold start + isolat).
class PendingNotificationStore {
  static const actionKey = 'fimus_pending_notification_action';
  static const dataKey = 'fimus_pending_notification_data';

  static Map<String, dynamic>? pendingData;
  static Map<String, dynamic>? pendingAction;

  static Future<void> persistAction(Map<String, dynamic> action) async {
    pendingAction = action;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(actionKey, jsonEncode(action));
    } catch (e) {
      debugPrint('Error persisting pending notification action: $e');
    }
  }

  static Future<void> persistData(Map<String, dynamic> data) async {
    pendingData = data;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(dataKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error persisting pending notification data: $e');
    }
  }

  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pendingAction == null) {
        final raw = prefs.getString(actionKey);
        if (raw != null) {
          pendingAction = jsonDecode(raw) as Map<String, dynamic>;
        }
      }
      if (pendingData == null) {
        final raw = prefs.getString(dataKey);
        if (raw != null) {
          pendingData = jsonDecode(raw) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Error restoring persisted notification pending: $e');
    }
  }

  static Future<void> clear({bool action = false, bool data = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (action) {
        pendingAction = null;
        await prefs.remove(actionKey);
      }
      if (data) {
        pendingData = null;
        await prefs.remove(dataKey);
      }
    } catch (_) {}
  }
}
