import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/api_config.dart';
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final _storage = const FlutterSecureStorage();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> init() async {
    // Request permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User declined or has not accepted permission');
    }

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
      },
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'monitrack_channel_id',
              'MoniTrack Notifications',
              channelDescription: 'Notifications for MoniTrack',
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    String? token = await _fcm.getToken();
    if (token != null) {
      print('FCM Token: $token');
      await _sendTokenToServer(token);
    }

    _fcm.onTokenRefresh.listen(_sendTokenToServer);
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      String? jwt = await _storage.read(key: 'auth_token');
      if (jwt != null) {
        // Here we send the token to the backend
        // Assuming ApiService.dio is configured with base URL
        var dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, headers: {
          'Authorization': 'Bearer $jwt',
          'Accept': 'application/json',
        }));
        
        await dio.post('/users/update-fcm-token', data: {
          'fcm_token': token,
        });
        print('FCM token sent to backend');
      }
    } catch (e) {
      print('Error sending FCM token to server: $e');
    }
  }

  Future<List<dynamic>> getNotifications() async {
    try {
      String? jwt = await _storage.read(key: 'auth_token');
      if (jwt != null) {
        var dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, headers: {
          'Authorization': 'Bearer $jwt',
          'Accept': 'application/json',
        }));
        
        var response = await dio.get('/notifications');
        return response.data['notifications'] ?? [];
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
    return [];
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      String? jwt = await _storage.read(key: 'auth_token');
      if (jwt != null) {
        var dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, headers: {
          'Authorization': 'Bearer $jwt',
          'Accept': 'application/json',
        }));
        
        await dio.post('/notifications/read', data: {
          'notification_id': notificationId,
        });
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      String? jwt = await _storage.read(key: 'auth_token');
      if (jwt != null) {
        var dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, headers: {
          'Authorization': 'Bearer $jwt',
          'Accept': 'application/json',
        }));
        
        await dio.post('/notifications/read-all');
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }
}
