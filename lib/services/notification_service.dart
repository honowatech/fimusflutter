import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/notification_model.dart';
import '../providers/account_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/notification_provider.dart';
import 'alerts/local_alerts_hook.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';
import '../utils/notification_channels.dart';
import 'auth_service.dart';
import 'notification_intent_queue.dart';
import 'notifications/inbox_repository.dart';
import 'notifications/local_notification_settings.dart';
import 'notifications/notification_navigator.dart';
import 'notifications/notification_texts.dart';
import 'notifications/pending_notification_store.dart';
import 'notifications/reminder_ids.dart';
import 'notifications/reminder_plan.dart';
import 'notifications/reminder_scheduler.dart';
import 'sync_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

const _badgeNotificationId = 0x00BAD6E;

/// Contrat `suppress_local` : le backend marque les pushs de rappel d'échéance
/// qu'il émet lui-même avec `source=server` et `suppress_local=true`. Dans ce
/// cas l'application doit annuler **son** rappel local pour la même dette,
/// sinon l'utilisateur serait notifié deux fois (une fois par le serveur, une
/// fois par l'alarme locale encore programmée).
///
/// Appelé dans les deux chemins : premier plan ([NotificationService._showLocal])
/// et isolat d'arrière-plan ([firebaseMessagingBackgroundHandler]).
///
/// Vrai si le `data` d'un push demande l'annulation du rappel local.
/// Fonction pure (testable sans plugin).
bool shouldSuppressLocalReminder(Map<String, dynamic> data) {
  if (data['suppress_local']?.toString().toLowerCase() != 'true') return false;
  if (data['type']?.toString() != 'debt_due_date_reminder') return false;
  final expenseUuid = data['expense_uuid']?.toString();
  return expenseUuid != null && expenseUuid.isNotEmpty;
}

/// Trace minimale d'une notification : jamais de titre, de corps ni de
/// montant — ces champs contiennent des données financières et `debugPrint`
/// reste actif en debug. Fonction pure (testable sans plugin).
String describeNotification(Map<String, dynamic>? data) {
  if (data == null) return 'type=? id=?';
  final type = data['type']?.toString() ?? '?';
  final id = (data['id'] ?? data['expense_uuid'] ?? data['account_uuid'])
          ?.toString() ??
      '?';
  return 'type=$type id=$id';
}

/// Idem à partir d'un payload JSON brut (isolat de tap).
String describeNotificationPayload(String? payload) {
  if (payload == null) return 'type=? id=?';
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) return describeNotification(decoded);
  } catch (_) {}
  return 'type=? id=?';
}

Future<void> suppressLocalReminderIfRequested(
  FlutterLocalNotificationsPlugin plugin,
  Map<String, dynamic> data,
) async {
  try {
    if (!shouldSuppressLocalReminder(data)) return;
    final expenseUuid = data['expense_uuid'].toString();
    await plugin.cancel(id: ReminderIds.debtNotificationId(expenseUuid));
    debugPrint('Local debt reminder suppressed (${describeNotification(data)})');
  } catch (e) {
    debugPrint('Error suppressing local debt reminder: $e');
  }
}

/// Handler FCM background : doit être enregistré AVANT runApp().
/// Voir `main()` — l'enregistrement y a lieu dès que Firebase est prêt,
/// conformément à la documentation FlutterFire (N19).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Idempotent : garantit le binding avant tout canal de plateforme
  // (SharedPreferences pour la langue, plugin de notifications locales).
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final data = message.data;
  debugPrint('Background message ${describeNotification(data)}');

  // Isolat d'arrière-plan : aucun état de l'isolat principal n'est visible,
  // la langue doit être relue sur disque avant tout texte affiché (N14).
  final texts = await NotificationTexts.loadLocale();

  // L'annulation du rappel local passe AVANT le filtre `notification != null` :
  // les rappels serveur d'échéance sont justement envoyés avec un bloc
  // `notification` (affiché nativement par le système). Si on sortait d'abord,
  // l'alarme locale resterait programmée et l'utilisateur serait notifié deux
  // fois pour la même échéance.
  if (shouldSuppressLocalReminder(data)) {
    final suppressPlugin = FlutterLocalNotificationsPlugin();
    await suppressPlugin.initialize(
        settings: localNotificationInitSettings(texts));
    await suppressLocalReminderIfRequested(suppressPlugin, data);
  }

  if (message.notification != null) return;

  final title = data['title'];
  final body = data['body'] ?? data['message'];
  if (title == null && body == null) return;

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(settings: localNotificationInitSettings(texts));

  final type = data['type']?.toString();
  final expenseUuid = data['expense_uuid']?.toString();
  final idSeed = type == 'scheduled_expense_due' && expenseUuid != null
      ? ReminderIds.scheduledIdSeed(expenseUuid)
      : data['id']?.toString() ?? expenseUuid ?? jsonEncode(data);

  await plugin.show(
    id: NotificationChannels.stableId(idSeed),
    title: title,
    body: body,
    notificationDetails: pushNotificationDetails(type, l10n: texts),
    payload: jsonEncode(data),
  );
}

/// Boutons d'action traités hors de l'isolat principal.
///
/// Une action Android sans `showsUserInterface` (et, plus généralement, tout
/// appui reçu alors que l'app est en tâche de fond) arrive ici, dans un isolat
/// séparé : les champs statiques de l'isolat principal n'y sont pas visibles.
/// On persiste donc l'intention sur disque (SharedPreferences), seul canal
/// partagé entre les deux isolats ; l'isolat principal la relit au démarrage
/// et à chaque retour au premier plan via [NotificationIntentQueue.drain].
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Trace réduite : ni titre, ni corps, ni montant (données financières).
  debugPrint('notificationTapBackground '
      '${describeNotificationPayload(notificationResponse.payload)} '
      'action=${notificationResponse.actionId ?? "-"}');
  // Indispensable : dans cet isolat le binding n'existe pas encore, or
  // SharedPreferences passe par un canal de plateforme.
  WidgetsFlutterBinding.ensureInitialized();
  _persistBackgroundTap(notificationResponse);
}

Future<void> _persistBackgroundTap(NotificationResponse response) async {
  // Le champ statique de PendingNotificationStore est conservé en complément
  // (cas où l'isolat serait partagé) : enqueueRawResponse écrit les deux.
  await NotificationIntentQueue.instance
      .enqueueRawResponse(response.actionId, response.payload);
}

/// Façade notifications : FCM, inbox, rappels locaux, navigation.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late final ReminderScheduler _scheduler;
  final InboxRepository _inbox = InboxRepository();
  final NotificationNavigator _navigator = NotificationNavigator();
  final NotificationIntentQueue _intents = NotificationIntentQueue.instance;

  static Map<String, dynamic>? get pendingNotificationData =>
      PendingNotificationStore.pendingData;
  static set pendingNotificationData(Map<String, dynamic>? value) =>
      PendingNotificationStore.pendingData = value;

  static Map<String, dynamic>? get pendingNotificationAction =>
      PendingNotificationStore.pendingAction;
  static set pendingNotificationAction(Map<String, dynamic>? value) =>
      PendingNotificationStore.pendingAction = value;

  bool get isInitialized => _scheduler.isReady;

  FirebaseMessaging get _messaging => _fcm ??= FirebaseMessaging.instance;

  NotificationService._internal() {
    _scheduler = ReminderScheduler(_localNotificationsPlugin);
  }

  Future<NotificationSettings> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    // N6 — stratégie unique d'affichage au premier plan : c'est TOUJOURS le
    // plugin local (_showLocal) qui affiche la bannière, sur iOS comme sur
    // Android. On désactive donc l'affichage natif iOS (alert/sound), sans
    // quoi iOS afficherait la notification FCM et _showLocal en afficherait
    // une seconde. Le badge reste géré par le système.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      try {
        final token = await _messaging.getToken();
        if (token != null) await _sendTokenToServer(token);
      } catch (e) {
        debugPrint('Error getting FCM token: $e');
      }
    }
    return settings;
  }

  Future<void> init() async {
    // Langue enregistrée relue avant toute création de canal ou de texte :
    // `init()` peut s'exécuter avant que LocaleProvider n'ait fini son propre
    // chargement asynchrone (N14).
    await NotificationTexts.loadLocale();

    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('Error initializing timezones: $e');
    }

    try {
      // Voir requestPermission() : l'affichage au premier plan est délégué au
      // plugin local pour éviter la double notification iOS (N6).
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );
    } catch (e) {
      debugPrint('Error setting foreground presentation options: $e');
    }

    // Les intentions ne sont exécutées que lorsque l'app est authentifiée et
    // déverrouillée ; sinon la file les garde pour un rejeu ultérieur.
    _intents
      ..onTap = _openFromNotification
      ..onAction = _performScheduledAction;

    await _localNotificationsPlugin.initialize(
      settings: localNotificationInitSettings(),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId != null && response.actionId!.isNotEmpty) {
          _handleNotificationAction(response.actionId!, response.payload);
          return;
        }
        if (response.payload != null) {
          try {
            handleNotificationData(
                jsonDecode(response.payload!) as Map<String, dynamic>);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _scheduler.isReady = true;

    await PendingNotificationStore.restore();
    // Lancement à froid depuis une notification locale : le callback
    // onDidReceiveNotificationResponse n'est pas rejoué, il faut interroger
    // le plugin explicitement (N3).
    await _captureLaunchDetails();

    // Lancement à froid depuis une notification FCM : lu AVANT les appels
    // réseau (getToken / _sendTokenToServer) pour supprimer la course au
    // démarrage — sinon MainScreen pouvait vider la file avant que le message
    // initial n'y soit déposé (N3).
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        await _intents.enqueueData(initialMessage.data);
      }
    } catch (e) {
      debugPrint('Error reading FCM initial message: $e');
    }

    await _createAndroidChannels();

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    try {
      final token = await _messaging.getToken();
      if (token != null) await _sendTokenToServer(token);
    } catch (e) {
      debugPrint('Error getting FCM token on init: $e');
    }
    _messaging.onTokenRefresh.listen(_sendTokenToServer);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNotificationData(message.data);
    });

    // Une intention a pu être déposée avant que MainScreen ne soit monté :
    // on tente un rejeu immédiat (sans effet si l'app est verrouillée).
    await _intents.drain();

    _reconcileScheduledAfterInit();
  }

  /// Crée les canaux Android et supprime ceux des versions précédentes.
  ///
  /// Les libellés sont traduits dans la langue courante au moment de la
  /// création : Android les fige ensuite. Un changement de langue en cours de
  /// session ne renomme donc pas les canaux, c'est le prochain démarrage qui
  /// s'en charge (comportement Android, pas un contournement possible).
  ///
  /// L'importance déclarée ici ne s'applique qu'à un canal *nouveau* : pour un
  /// identifiant déjà connu de l'appareil, Android conserve l'importance
  /// existante (l'utilisateur en est propriétaire).
  Future<void> _createAndroidChannels() async {
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;
    for (final c in androidNotificationChannels(NotificationTexts.current)) {
      await androidPlugin.createNotificationChannel(c);
    }
    for (final legacyId in NotificationChannels.legacy) {
      try {
        await androidPlugin.deleteNotificationChannel(channelId: legacyId);
      } catch (_) {}
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final notifTitle = notification?.title ?? data['title'];
    final notifBody = notification?.body ?? data['body'] ?? data['message'];
    // Contrat `suppress_local` : on annule le rappel local AVANT d'afficher le
    // push serveur, pour ne jamais notifier deux fois la même échéance.
    await suppressLocalReminderIfRequested(_localNotificationsPlugin, data);
    if (notifTitle != null || notifBody != null) {
      // Affichage unique, sur les deux plateformes : l'affichage natif iOS au
      // premier plan est désactivé (setForegroundNotificationPresentationOptions
      // alert: false), c'est ce _showLocal qui fait foi. Il porte aussi les
      // boutons d'action et la catégorie iOS, que la bannière FCM n'aurait pas.
      await _showLocal(data, notifTitle, notifBody);
    }
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.read<NotificationProvider>().addFromPush(message.data);
    }
    syncAndRefreshProviders();
  }

  Future<void> _showLocal(
      Map<String, dynamic> data, String? title, String? body) async {
    final type = data['type']?.toString();
    final expenseUuid = data['expense_uuid']?.toString();
    final idSeed = type == 'scheduled_expense_due' && expenseUuid != null
        ? ReminderIds.scheduledIdSeed(expenseUuid)
        : data['id']?.toString() ?? expenseUuid ?? jsonEncode(data);
    await _localNotificationsPlugin.show(
      id: NotificationChannels.stableId(idSeed),
      title: title,
      body: body,
      notificationDetails: pushNotificationDetails(type),
      payload: jsonEncode(data),
    );
  }

  /// Replanifie les rappels après un changement de préférences (heure de
  /// rappel, heures calmes, interrupteurs) : l'empreinte des rappels déjà
  /// posés change, le diff de [ReminderScheduler] se charge du reste.
  Future<void> reconcileAfterPreferencesChange() =>
      _reconcileScheduledAfterInit();

  Future<void> _reconcileScheduledAfterInit() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          await context
              .read<ExpenseProvider>()
              .reconcileScheduledNotifications(force: true);
          return;
        }
      } catch (e) {
        debugPrint('Error reconciling scheduled notifications on init: $e');
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Réconciliation idempotente des rappels locaux (N18) : voir
  /// [ReminderScheduler.reconcile].
  Future<void> reconcileReminders(
    List<ReminderRequest> requests, {
    bool force = false,
  }) =>
      _scheduler.reconcile(requests, force: force);

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
      final syncFuture = SyncService().fullSync();
      if (context != null && context.mounted) {
        context.read<NotificationProvider>().fetch();
      }
      await syncFuture;
      if (context != null && context.mounted) {
        context.read<AccountProvider>().loadData();
        final expenses = context.read<ExpenseProvider>();
        // Après une synchronisation, une dette ou une programmation créée sur
        // un autre appareil doit obtenir son rappel local ici : on force la
        // réconciliation (elle est idempotente, seul le delta est appliqué).
        expenses
            .loadData()
            .then((_) => expenses.reconcileScheduledNotifications(force: true));
        context.read<ContactProvider>().fetchContacts();
        // Une synchronisation fait bouger les soldes et vide la file d'envoi :
        // c'est le moment d'évaluer les alertes locales (budget, solde bas,
        // données non synchronisées).
        runLocalAlerts(context, force: true);
      }
      _lastSyncTime = DateTime.now();
    } catch (e) {
      debugPrint('Error syncing on notification: $e');
    } finally {
      _isSyncing = false;
    }
  }

  String? _lastSyncedToken;
  Future<void>? _syncFcmFuture;

  Future<void> syncFcmToken() {
    return _syncFcmFuture ??= _performSyncFcmToken();
  }

  Future<void> _performSyncFcmToken() async {
    try {
      final token = await _messaging.getToken();
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

  /// Enregistre le jeton FCM côté serveur.
  ///
  /// `device_id` est **indispensable** (sprint 5) : c'est lui qui rattache le
  /// jeton à une ligne `user_devices` identifiée. Sans lui :
  ///  * l'appareil qui vient de se connecter n'est pas reconnu et reçoit sa
  ///    propre alerte « nouvelle connexion » ;
  ///  * l'action « Ce n'était pas moi » ne peut épargner aucun jeton et
  ///    supprime ceux de **tous** les appareils du compte, y compris celui qui
  ///    déclenche l'action (cf. `SecurityController::revokeOtherSessions`).
  ///
  /// `device_model` complète le libellé affiché dans l'alerte.
  Future<void> _sendTokenToServer(String token) async {
    try {
      final auth = AuthService();
      if (await auth.hasToken()) {
        final model = AuthService.deviceModel;
        await ApiClient.instance.post(
          '${ApiConfig.baseUrl}/users/update-fcm-token',
          data: {
            'fcm_token': token,
            'device_id': await auth.getDeviceId(),
            'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
            if (model != null && model.isNotEmpty) 'device_model': model,
            'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
          },
        );
        debugPrint('FCM token sent to backend');
      }
    } catch (e) {
      debugPrint('Error sending FCM token to server: $e');
    }
  }

  Future<NotificationPageResult> getNotifications({int page = 1}) =>
      _inbox.fetchPage(page: page);

  Future<List<NotificationModel>> loadCachedNotifications() =>
      _inbox.loadCache();

  Future<void> saveCachedNotifications(List<NotificationModel> items) =>
      _inbox.saveCache(items);

  Future<void> upsertCachedNotification(NotificationModel notification) =>
      _inbox.upsertCache(notification);

  Future<void> deleteCachedNotifications(List<String> ids) =>
      _inbox.deleteCache(ids);

  Future<bool> markAsRead(String notificationId) =>
      _inbox.markAsRead(notificationId);

  Future<bool> markAllAsRead() => _inbox.markAllAsRead();

  Future<bool> deleteNotifications(List<String> notificationIds) =>
      _inbox.deleteNotifications(notificationIds);

  Future<void> scheduleDebtDueDateReminder({
    required String expenseId,
    required String title,
    required double amount,
    required String currency,
    required DateTime dueDate,
    required bool isDebt,
    String? contactName,
  }) {
    return _scheduler.scheduleDebtDueDateReminder(
      expenseId: expenseId,
      amount: amount,
      currency: currency,
      dueDate: dueDate,
      isDebt: isDebt,
      contactName: contactName,
    );
  }

  Future<void> cancelDebtDueDateReminder(String expenseId) =>
      _scheduler.cancelDebtDueDateReminder(expenseId);

  Future<void> scheduleScheduledExpenseReminder({
    required String expenseId,
    required String title,
    required double amount,
    required String currency,
    required DateTime reminderAt,
  }) {
    return _scheduler.scheduleScheduledExpenseReminder(
      expenseId: expenseId,
      title: title,
      amount: amount,
      currency: currency,
      reminderAt: reminderAt,
    );
  }

  Future<void> cancelScheduledExpenseReminder(String expenseId) =>
      _scheduler.cancelScheduledExpenseReminder(expenseId);

  Future<void> cancelAllScheduledExpenseReminders() =>
      _scheduler.cancelAllByPayloadContains('scheduled_expense_due');

  Future<void> cancelAllDebtDueDateReminders() =>
      _scheduler.cancelAllByPayloadContains('debt_due_date_reminder');

  /// Met à jour la pastille (badge) de l'icône iOS (N20).
  ///
  /// flutter_local_notifications n'expose pas d'API de badge directe : le
  /// badge est porté par `content.badge` d'une notification. On publie donc
  /// une notification « porteuse » muette dont le seul rôle est d'appliquer
  /// [count]. `badgeNumber: 0` **remet le badge à zéro** : c'est le chemin
  /// emprunté par `NotificationProvider` quand tout est lu
  /// (`markAllAsRead`, `clear`, ou un `unreadCount` retombé à 0).
  ///
  /// Trois garde-fous par rapport à la version précédente :
  ///  * appel restreint à iOS — sur Android, `NotificationDetails` sans bloc
  ///    `android` publierait (ou ferait échouer) une notification vide ; le
  ///    compteur y est de toute façon géré par le lanceur ;
  ///  * `presentBanner`/`presentList` explicitement à `false` : sans cela le
  ///    plugin retombe sur les valeurs par défaut (`true`) et la porteuse,
  ///    sans titre ni corps, apparaît dans le centre de notifications ;
  ///  * la porteuse précédente est retirée **avant** d'en publier une
  ///    nouvelle, plutôt qu'après (le retrait immédiat pouvait intervenir
  ///    avant que le système n'ait appliqué le badge).
  Future<void> updateBadge(int count) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final badge = count < 0 ? 0 : count;
    try {
      await _localNotificationsPlugin.cancel(id: _badgeNotificationId);
      await _localNotificationsPlugin.show(
        id: _badgeNotificationId,
        title: null,
        body: null,
        notificationDetails: NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBanner: false,
            presentList: false,
            presentSound: false,
            presentBadge: true,
            badgeNumber: badge,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error updating iOS badge: $e');
    }
  }

  /// Point d'entrée d'un bouton d'action reçu dans l'isolat principal.
  /// La décision « exécuter maintenant ou mettre en file » revient à la file
  /// d'intentions, qui vérifie authentification + verrou PIN (N1).
  Future<void> _handleNotificationAction(
      String actionId, String? payload) async {
    if (actionId != 'scheduled_confirm' && actionId != 'scheduled_cancel') {
      return;
    }
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final expenseId = data['expense_uuid']?.toString();
      if (expenseId == null || expenseId.isEmpty) return;
      await _intents.submitAction(actionId, expenseId);
    } catch (e) {
      debugPrint('Error handling notification action: $e');
    }
  }

  /// Exécution effective d'un bouton d'action : appelée uniquement par la file
  /// d'intentions, donc app authentifiée et déverrouillée.
  Future<void> _performScheduledAction(
      String actionId, String expenseId) async {
    try {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        await PendingNotificationStore.persistAction(
            {'action': actionId, 'expense_uuid': expenseId});
        return;
      }

      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      await provider.loadData();
      if (!context.mounted) {
        await PendingNotificationStore.persistAction(
            {'action': actionId, 'expense_uuid': expenseId});
        return;
      }

      if (actionId == 'scheduled_confirm') {
        final ok = await provider.confirmScheduledExpense(expenseId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? AppLocalizations.of(context)!.scheduledExpenseConfirmed
                  : AppLocalizations.of(context)!.scheduledExpensesEmpty,
            ),
          ),
        );
      } else {
        final ok = await provider.cancelScheduledExpense(expenseId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? AppLocalizations.of(context)!.scheduledExpenseCancelled
                  : AppLocalizations.of(context)!.scheduledExpensesEmpty,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling notification action: $e');
    }
  }

  /// Rejoue les intentions en attente (démarrage, déverrouillage, reprise).
  /// Sans effet si l'app est encore verrouillée ou non authentifiée.
  Future<void> consumePendingOnLaunch() => _intents.drain();

  /// Conservé pour compatibilité : relit l'action persistée (y compris celle
  /// écrite par l'isolat d'arrière-plan) et la rejoue via la file (N2).
  Future<void> applyPendingNotificationAction() => _intents.drain();

  /// Point d'entrée d'un tap de notification (locale ou FCM).
  void handleNotificationData(Map<String, dynamic> data) {
    _intents.submitTap(data);
  }

  Future<void> _openFromNotification(Map<String, dynamic> data) async {
    syncAndRefreshProviders();
    await _navigator.open(data);
  }

  /// Lancement à froid : le plugin conserve la réponse qui a démarré le
  /// process (tap ou bouton). On la dépose dans la file sans l'exécuter, le
  /// rejeu ayant lieu une fois l'utilisateur authentifié et déverrouillé.
  Future<void> _captureLaunchDetails() async {
    try {
      final details =
          await _localNotificationsPlugin.getNotificationAppLaunchDetails();
      if (details == null || details.didNotificationLaunchApp != true) return;
      final response = details.notificationResponse;
      if (response == null) return;
      await _intents.enqueueRawResponse(response.actionId, response.payload);
    } catch (e) {
      debugPrint('Error reading notification launch details: $e');
    }
  }
}
