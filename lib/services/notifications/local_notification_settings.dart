import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/notification_channels.dart';
import 'notification_texts.dart';

const statusNotificationIcon = '@drawable/ic_stat_fimus';
const scheduledCategoryId = 'scheduled_expense';

InitializationSettings localNotificationInitSettings([AppLocalizations? l10n]) {
  final texts = l10n ?? NotificationTexts.current;
  return InitializationSettings(
    android: const AndroidInitializationSettings(statusNotificationIcon),
    iOS: DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          scheduledCategoryId,
          actions: [
            DarwinNotificationAction.plain(
              'scheduled_confirm',
              texts.scheduledConfirmAction,
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              'scheduled_cancel',
              texts.scheduledCancelAction,
              options: {
                DarwinNotificationActionOption.destructive,
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        ),
      ],
    ),
  );
}

/// Définition complète d'un canal Android : identité (miroir du backend),
/// hiérarchie d'importance (N15) et libellés traduits (N14).
@immutable
class AndroidChannelSpec {
  const AndroidChannelSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
    required this.priority,
    required this.playSound,
  });

  final String id;
  final String name;
  final String description;
  final Importance importance;
  final Priority priority;
  final bool playSound;

  bool get vibrate => playSound;

  AndroidNotificationChannel toChannel() => AndroidNotificationChannel(
    id,
    name,
    description: description,
    importance: importance,
    playSound: playSound,
    enableVibration: vibrate,
  );
}

/// Hiérarchie d'importance des canaux (N15). Fonction pure, testable sans
/// plugin : une dette prime sur un rappel de dépense, qui prime sur une
/// information de contact ; une annonce marketing ne doit jamais interrompre.
Importance androidImportanceForChannel(String channelId) {
  switch (channelId) {
    case NotificationChannels.debts:
      return Importance.max;
    case NotificationChannels.scheduledExpenses:
      return Importance.high;
    // Alertes locales de finances (budget, solde bas, données non
    // synchronisées) : actionnables, elles doivent être vues le jour même.
    case NotificationChannels.alerts:
      return Importance.high;
    case NotificationChannels.contacts:
    case NotificationChannels.jointAccounts:
    case NotificationChannels.general:
      return Importance.defaultImportance;
    case NotificationChannels.announcements:
      return Importance.low;
    default:
      return Importance.defaultImportance;
  }
}

/// Priorité Android (pré-Oreo) alignée sur l'importance. Fonction pure.
Priority androidPriorityForChannel(String channelId) {
  switch (androidImportanceForChannel(channelId)) {
    case Importance.max:
      return Priority.high;
    case Importance.high:
      return Priority.high;
    case Importance.low:
      return Priority.low;
    case Importance.min:
      return Priority.min;
    default:
      return Priority.defaultPriority;
  }
}

/// Un canal sonne, sauf les annonces (N15 : `low`, sans son ni vibration).
/// Fonction pure.
bool androidPlaySoundForChannel(String channelId) =>
    channelId != NotificationChannels.announcements;

/// Libellés traduits + importance d'un canal. Un identifiant inconnu retombe
/// sur le canal général, comme le mapping type → canal.
AndroidChannelSpec androidChannelSpec(
  String channelId,
  AppLocalizations texts,
) {
  final id = NotificationChannels.all.contains(channelId)
      ? channelId
      : NotificationChannels.general;
  final String name;
  final String description;
  switch (id) {
    case NotificationChannels.debts:
      name = texts.notifChannelDebtsName;
      description = texts.notifChannelDebtsDesc;
    case NotificationChannels.scheduledExpenses:
      name = texts.notifChannelScheduledExpensesName;
      description = texts.notifChannelScheduledExpensesDesc;
    case NotificationChannels.contacts:
      name = texts.notifChannelContactsName;
      description = texts.notifChannelContactsDesc;
    case NotificationChannels.jointAccounts:
      name = texts.notifChannelJointAccountsName;
      description = texts.notifChannelJointAccountsDesc;
    case NotificationChannels.announcements:
      name = texts.notifChannelAnnouncementsName;
      description = texts.notifChannelAnnouncementsDesc;
    case NotificationChannels.alerts:
      name = texts.notifChannelAlertsName;
      description = texts.notifChannelAlertsDesc;
    default:
      name = texts.notifChannelGeneralName;
      description = texts.notifChannelGeneralDesc;
  }
  return AndroidChannelSpec(
    id: id,
    name: name,
    description: description,
    importance: androidImportanceForChannel(id),
    priority: androidPriorityForChannel(id),
    playSound: androidPlaySoundForChannel(id),
  );
}

List<AndroidChannelSpec> androidChannelSpecs(AppLocalizations texts) => [
  for (final id in NotificationChannels.all) androidChannelSpec(id, texts),
];

/// Canaux à créer au démarrage.
///
/// Les libellés sont figés à la création par Android : un changement de langue
/// en cours de session ne renomme pas les canaux déjà créés (ils sont
/// renommés au prochain démarrage de l'application).
List<AndroidNotificationChannel> androidNotificationChannels([
  AppLocalizations? l10n,
]) => [
  for (final spec in androidChannelSpecs(l10n ?? NotificationTexts.current))
    spec.toChannel(),
];

/// Détails d'affichage d'une notification poussée (premier plan ou isolat
/// d'arrière-plan) : canal, importance et libellés dérivés du `type` du
/// payload, pour ne plus dupliquer de chaînes codées en dur.
NotificationDetails pushNotificationDetails(
  String? type, {
  AppLocalizations? l10n,
}) {
  final texts = l10n ?? NotificationTexts.current;
  final spec = androidChannelSpec(
    NotificationChannels.androidChannelIdForType(type),
    texts,
  );
  return NotificationDetails(
    android: AndroidNotificationDetails(
      spec.id,
      spec.name,
      channelDescription: spec.description,
      icon: statusNotificationIcon,
      importance: spec.importance,
      priority: spec.priority,
      playSound: spec.playSound,
      enableVibration: spec.vibrate,
      visibility: NotificationVisibility.public,
      groupKey: NotificationChannels.androidGroupKey(type),
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: spec.playSound,
      categoryIdentifier: type == 'scheduled_expense_due'
          ? scheduledCategoryId
          : null,
    ),
  );
}
