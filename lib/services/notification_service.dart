import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import '../utils/api_config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../screens/contacts_screen.dart';
import '../screens/main_screen.dart';
import '../screens/debt_detail_screen.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/contact_provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background message ${message.messageId}');
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('notificationTapBackground: ${notificationResponse.payload}');
  if (notificationResponse.payload != null) {
    try {
      final data = jsonDecode(notificationResponse.payload!);
      NotificationService.pendingNotificationData = data;
    } catch (e) {
      debugPrint('Error parsing background payload: $e');
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  static Map<String, dynamic>? pendingNotificationData;

  late final Dio _dio;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal() {
    _dio = Dio();
    _dio.options.headers['Accept'] = 'application/json';

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await AuthService().getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<NotificationSettings> requestPermission() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      try {
        String? token = await _fcm.getToken();
        if (token != null) {
          await _sendTokenToServer(token);
        }
      } catch (e) {
        debugPrint('Error getting FCM token: $e');
      }
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    return settings;
  }

  Future<void> init() async {
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
        debugPrint('Notification tapped: ${response.payload}');
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            _handleNotificationTap(data);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final List<AndroidNotificationChannel> channels = [
      const AndroidNotificationChannel(
        'fimus_transactions_v2_debts',
        'Dettes et Remboursements',
        description: 'Notifications liées aux dettes partagées',
        importance: Importance.max,
      ),
      const AndroidNotificationChannel(
        'fimus_transactions_v2_contacts',
        'Contacts',
        description: 'Notifications liées à vos contacts',
        importance: Importance.max,
      ),
      const AndroidNotificationChannel(
        'fimus_transactions_v2_joint_accounts',
        'Comptes conjoints',
        description: 'Notifications liées aux comptes partagés',
        importance: Importance.max,
      ),
      const AndroidNotificationChannel(
        'fimus_general_v2',
        'Général',
        description: 'Notifications générales',
        importance: Importance.max,
      )
    ];

    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
    if (androidPlugin != null) {
      for (var c in channels) {
        await androidPlugin.createNotificationChannel(c);
      }
      await androidPlugin.deleteNotificationChannel(channelId: 'monitrack_channel_id');
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      RemoteNotification? notification = message.notification;

      if (notification != null) {
        String channelId = 'fimus_general_v2';
        final type = message.data['type'];
        if (type == 'new_debt' || type == 'debt_updated' || type == 'debt_rejected' || type == 'new_joint_debt' || type == 'debt_created') {
          channelId = 'fimus_transactions_v2_debts';
        } else if (type == 'contact_added') {
          channelId = 'fimus_transactions_v2_contacts';
        } else if (type == 'joint_account_added') {
          channelId = 'fimus_transactions_v2_joint_accounts';
        }

        int notificationId = notification.hashCode;
        if (message.data.containsKey('id')) {
          notificationId = message.data['id'].hashCode;
        } else if (message.data.containsKey('expense_uuid')) {
          notificationId = message.data['expense_uuid'].hashCode;
        }

        _localNotificationsPlugin.show(
          id: notificationId,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              'FIMUS Notifications',
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              visibility: NotificationVisibility.private,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }

      // Mise à jour instantanée du badge et de la liste in-app
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        context.read<NotificationProvider>().addFromPush(message.data);
      }

      // Sync en arrière-plan (non bloquante)
      syncAndRefreshProviders();
    });

    String? token = await _fcm.getToken();
    if (token != null) {
      await _sendTokenToServer(token);
    }

    _fcm.onTokenRefresh.listen(_sendTokenToServer);

    // Handle background taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    // Handle terminated taps
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      pendingNotificationData = initialMessage.data;
    }
  }

  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  Future<void> syncAndRefreshProviders() async {
    if (_isSyncing) return;
    
    final now = DateTime.now();
    if (_lastSyncTime != null && now.difference(_lastSyncTime!).inSeconds < 2) {
      return;
    }
    
    _isSyncing = true;
    try {
      final context = navigatorKey.currentContext;

      // Rafraîchir les notifications immédiatement (appel API léger)
      // en parallèle avec le fullSync (opération lourde)
      final syncFuture = SyncService().fullSync();
      if (context != null && context.mounted) {
        context.read<NotificationProvider>().fetch();
      }

      // Attendre la fin du sync, puis rafraîchir les données lourdes
      await syncFuture;
      if (context != null && context.mounted) {
        context.read<AccountProvider>().loadData();
        context.read<ExpenseProvider>().loadData();
        context.read<ContactProvider>().fetchContacts();
      }

      _lastSyncTime = DateTime.now();
    } catch (e) {
      debugPrint('Error syncing on notification: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    debugPrint('Handling notification tap with data: $data');

    // Sync en arrière-plan — navigation immédiate
    syncAndRefreshProviders();

    final type = data['type'];
    final context = navigatorKey.currentContext;
    if (context == null) {
      pendingNotificationData = data;
      return;
    }

    if (type == 'contact_added') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen()));
    } else if (type == 'joint_account_added') {
      MainScreen.of(context)?.setSelectedIndex(0);
    } else if (type == 'new_joint_debt' || type == 'debt_updated' || type == 'debt_created' || type == 'new_debt' || type == 'debt_rejected') {
      final expenseUuid = (data['expense_uuid'] ?? data['expense_id'] ?? data['id'])?.toString();
      if (expenseUuid != null && expenseUuid.isNotEmpty) {
        final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
        try {
          final expense = expenseProvider.expenses.firstWhere((e) => e.id.toString() == expenseUuid);
          if (expense.debtTag != null && expense.debtTag!.isNotEmpty) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => DebtDetailScreen(debtTag: expense.debtTag!)));
            return;
          }
        } catch (e) {
          // L'opération n'est pas encore synchronisée localement, on redirige vers l'écran Dettes par défaut.
        }
      }
      MainScreen.of(context)?.setSelectedIndex(2);
    }
  }

  String? _lastSyncedToken;
  Future<void>? _syncFcmFuture;

  Future<void> syncFcmToken() {
    _syncFcmFuture ??= _performSyncFcmToken();
    return _syncFcmFuture!;
  }

  Future<void> _performSyncFcmToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null && token != _lastSyncedToken) {
        await _sendTokenToServer(token);
        _lastSyncedToken = token;
      }
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    } finally {
      _syncFcmFuture = null;
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      if (await AuthService().hasToken()) {
        await _dio.post('${ApiConfig.baseUrl}/users/update-fcm-token', data: {
          'fcm_token': token,
          'platform': Platform.operatingSystem,
          'locale': Platform.localeName,
        });
        debugPrint('FCM token sent to backend');
      }
    } catch (e) {
      debugPrint('Error sending FCM token to server: $e');
    }
  }

  Future<List<NotificationModel>> getNotifications() async {
    try {
      if (await AuthService().hasToken()) {
        var response = await _dio.get('${ApiConfig.baseUrl}/notifications');
        final notificationsData = response.data['notifications'] as List<dynamic>? ?? [];
        return notificationsData.map((e) => NotificationModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
    return [];
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      if (await AuthService().hasToken()) {
        final response = await _dio.post('${ApiConfig.baseUrl}/notifications/read', data: {
          'notification_id': notificationId,
        });
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
        final response = await _dio.post('${ApiConfig.baseUrl}/notifications/delete', data: {
          'notification_ids': notificationIds,
        });
        return response.statusCode == 200 || response.statusCode == 204;
      }
    } catch (e) {
      debugPrint('Error deleting notifications: $e');
    }
    return false;
  }

  void handleNotificationData(Map<String, dynamic> data) {
    _handleNotificationTap(data);
  }
}
