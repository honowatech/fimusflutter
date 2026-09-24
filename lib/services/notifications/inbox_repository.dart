import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/notification_model.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../auth_service.dart';
import '../database_service.dart';

class InboxRepository {
  /// Horodatage (ISO 8601 UTC) de la dernière synchronisation serveur réussie.
  /// Sert au bandeau « hors ligne / données du … » après un redémarrage.
  static const String _lastSyncKey = 'inbox_last_sync_at';

  Dio get _dio => ApiClient.instance;

  Future<NotificationPageResult> fetchPage({int page = 1}) async {
    try {
      if (await AuthService().hasToken()) {
        final response = await _dio.get(
          '${ApiConfig.baseUrl}/notifications',
          queryParameters: {'page': page},
        );
        final body = response.data;
        if (body is! Map) {
          debugPrint('Unexpected notifications payload: ${body.runtimeType}');
          return const NotificationPageResult(items: [], success: false);
        }
        final notificationsData = body['notifications'] as List<dynamic>? ?? [];
        return NotificationPageResult(
          items: notificationsData
              .map((e) => NotificationModel.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList(),
          currentPage: (body['current_page'] as num?)?.toInt() ?? page,
          lastPage: (body['last_page'] as num?)?.toInt() ?? page,
          unreadCount: (body['unread_count'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return const NotificationPageResult(items: [], success: false);
    }
    return const NotificationPageResult(items: [], success: false);
  }

  Future<List<NotificationModel>> loadCache() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows =
          await db.query('inbox_notifications', orderBy: 'created_at DESC');
      return rows.map(NotificationModel.fromDbMap).toList();
    } catch (e) {
      debugPrint('Error loading cached notifications: $e');
      return [];
    }
  }

  /// Date de la dernière synchronisation réussie, conservée entre deux
  /// lancements pour afficher « données du … » quand on repart du cache.
  Future<DateTime?> loadLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastSyncKey);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    } catch (e) {
      debugPrint('Error loading inbox last sync: $e');
      return null;
    }
  }

  Future<void> saveLastSync(DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, at.toUtc().toIso8601String());
    } catch (e) {
      debugPrint('Error saving inbox last sync: $e');
    }
  }

  Future<void> clearLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSyncKey);
    } catch (e) {
      debugPrint('Error clearing inbox last sync: $e');
    }
  }

  Future<void> saveCache(List<NotificationModel> items) async {
    try {
      final db = await DatabaseService.instance.database;
      await db.transaction((txn) async {
        await txn.delete('inbox_notifications');
        for (final n in items) {
          await txn.insert(
            'inbox_notifications',
            n.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      debugPrint('Error saving cached notifications: $e');
    }
  }

  Future<void> upsertCache(NotificationModel notification) async {
    try {
      final db = await DatabaseService.instance.database;
      await db.insert(
        'inbox_notifications',
        notification.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error upserting cached notification: $e');
    }
  }

  Future<void> deleteCache(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await DatabaseService.instance.database;
      await db.delete(
        'inbox_notifications',
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
    } catch (e) {
      debugPrint('Error deleting cached notifications: $e');
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      if (await AuthService().hasToken()) {
        final response = await _dio.post(
          '${ApiConfig.baseUrl}/notifications/read',
          data: {'notification_id': notificationId},
        );
        return response.statusCode == 200 || response.statusCode == 204;
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
    return false;
  }

  Future<bool> markAllAsRead() async {
    try {
      if (await AuthService().hasToken()) {
        final response = await _dio.post('${ApiConfig.baseUrl}/notifications/read-all');
        return response.statusCode == 200 || response.statusCode == 204;
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
    return false;
  }

  Future<bool> deleteNotifications(List<String> notificationIds) async {
    try {
      if (await AuthService().hasToken()) {
        final response = await _dio.post(
          '${ApiConfig.baseUrl}/notifications/delete',
          data: {'notification_ids': notificationIds},
        );
        return response.statusCode == 200 || response.statusCode == 204;
      }
    } catch (e) {
      debugPrint('Error deleting notifications: $e');
    }
    return false;
  }
}
