import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  /// Injecte instantanément une notification depuis les données du push FCM
  /// dans la liste locale, sans attendre l'API. Sera remplacée au prochain fetch().
  void addFromPush(Map<String, dynamic> pushData) {
    final notification = NotificationModel(
      id: 'push_${DateTime.now().millisecondsSinceEpoch}',
      data: pushData,
      createdAt: DateTime.now().toIso8601String(),
    );
    _notifications.insert(0, notification);
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();

    _notifications = await NotificationService().getNotifications();
    _unreadCount = _notifications.where((n) => !n.isRead).length;

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> markAsRead(String id, int index) async {
    if (index < 0 || index >= _notifications.length) return false;
    
    final previousReadAt = _notifications[index].readAt;
    _notifications[index].readAt = DateTime.now().toIso8601String();
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
    
    final success = await NotificationService().markAsRead(id);
    if (!success) {
      _notifications[index].readAt = previousReadAt;
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> markAllAsRead() async {
    final unreadIndices = <int>[];
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        unreadIndices.add(i);
        _notifications[i].readAt = DateTime.now().toIso8601String();
      }
    }
    
    _unreadCount = 0;
    notifyListeners();

    final success = await NotificationService().markAllAsRead();
    if (!success) {
      for (final i in unreadIndices) {
        _notifications[i].readAt = null;
      }
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> deleteNotifications(List<String> ids) async {
    // Optimistic deletion
    final deletedNotifications = _notifications.where((n) => ids.contains(n.id)).toList();
    _notifications.removeWhere((n) => ids.contains(n.id));
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();

    final success = await NotificationService().deleteNotifications(ids);
    if (!success) {
      // Revert if failed
      _notifications.addAll(deletedNotifications);
      _notifications.sort((a, b) {
        if (a.createdAt == null || b.createdAt == null) return 0;
        return DateTime.parse(b.createdAt!).compareTo(DateTime.parse(a.createdAt!));
      });
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
      return false;
    }
    return true;
  }
}
