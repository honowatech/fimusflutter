import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationPermissionService extends ChangeNotifier {
  bool _isGranted = true;

  bool get isGranted => _isGranted;

  Future<void> checkPermission() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    _isGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
                 settings.authorizationStatus == AuthorizationStatus.provisional;
    notifyListeners();
  }

  Future<void> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _isGranted = settings.authorizationStatus == AuthorizationStatus.authorized;
    notifyListeners();
  }
}
