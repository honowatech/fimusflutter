/// Identifiants des canaux Android et dérivation d'un id de notification stable.
///
/// Miroir exact de `Backend/config/notifications.php` (clé `android.channels`)
/// : le backend choisit le canal du push, l'application le crée et l'utilise
/// pour les notifications locales. Toute entrée ajoutée ici doit l'être aussi
/// côté serveur, sinon le push retombe sur le canal par défaut.
///
/// Les **noms et descriptions** visibles par l'utilisateur ne sont pas ici :
/// ils sont traduits (ARB) et assemblés dans
/// `lib/services/notifications/local_notification_settings.dart`.
class NotificationChannels {
  static const general = 'fimus_general_v3';
  static const debts = 'fimus_transactions_v3_debts';
  static const contacts = 'fimus_transactions_v3_contacts';
  static const jointAccounts = 'fimus_transactions_v3_joint_accounts';
  static const scheduledExpenses = 'fimus_scheduled_expenses_v3';

  /// Annonces / campagnes marketing (`mass_broadcast`) : canal discret et
  /// silencieux, séparé du canal « Général » pour que l'utilisateur puisse le
  /// couper sans perdre les notifications de service.
  static const announcements = 'fimus_announcements_v3';

  /// Alertes locales de finances personnelles (sprint 4) : seuil de budget par
  /// catégorie, solde bas par compte, données non synchronisées.
  ///
  /// Ces trois types ne sont **jamais** poussés par le serveur : ils sont
  /// calculés et affichés par l'appareil (`LocalAlertsService`). L'entrée
  /// correspondante côté `Backend/config/notifications.php` n'existe donc que
  /// pour garder les deux mappings alignés (test de miroir).
  static const alerts = 'fimus_alerts_v3';

  /// Types locaux routés vers [alerts]. Listés à part pour que les modules
  /// d'alertes ne recopient pas les chaînes.
  static const budgetThresholdType = 'budget_threshold';
  static const lowBalanceType = 'low_balance';
  static const unsyncedDataType = 'unsynced_data';

  /// Types serveur du sprint 5, tous deux routés vers [general] (miroir de
  /// `Backend/config/notifications.php`, qui les mappe explicitement sur
  /// `fimus_general_v3`).
  ///
  /// Le bilan hebdomadaire est un résumé : ni urgent ni actionnable, il a sa
  /// place sur le canal de service. L'alerte de nouvelle connexion, elle,
  /// mériterait un canal « Sécurité » dédié — elle n'en a pas encore, faute
  /// de libellés traduits ; elle passe donc par le canal général, comme côté
  /// serveur. Les deux entrées sont écrites explicitement (et non laissées au
  /// `default`) pour que l'intention reste lisible et que le test de miroir
  /// avec le backend couvre bien ces types.
  static const weeklyDigestType = 'weekly_digest';
  static const newLoginType = 'new_login';

  /// Tous les canaux créés au démarrage.
  static const all = <String>[
    debts,
    scheduledExpenses,
    contacts,
    jointAccounts,
    general,
    announcements,
    alerts,
  ];

  /// Canaux des versions précédentes, supprimés au démarrage pour ne pas
  /// laisser d'entrées mortes dans les réglages Android.
  static const legacy = <String>[
    'monitrack_channel_id',
    'fimus_general_v2',
    'fimus_transactions_v2_debts',
    'fimus_transactions_v2_contacts',
    'fimus_transactions_v2_joint_accounts',
  ];

  /// Canal Android correspondant au type métier du payload FCM / local.
  /// Fonction pure (testable sans plugin) : miroir du mapping backend.
  static String androidChannelIdForType(String? type) {
    switch (type) {
      case 'new_debt':
      case 'debt_updated':
      case 'debt_rejected':
      case 'new_joint_debt':
      case 'debt_created':
      case 'debt_due_date_reminder':
        return debts;
      case 'contact_added':
        return contacts;
      case 'joint_account_added':
        return jointAccounts;
      case 'scheduled_expense_due':
        return scheduledExpenses;
      case 'mass_broadcast':
        return announcements;
      // Alertes locales (sprint 4). Ajout purement additif : aucun type
      // existant ne change de canal.
      case budgetThresholdType:
      case lowBalanceType:
      case unsyncedDataType:
        return alerts;
      // Sprint 5 : bilan hebdomadaire et alerte de nouvelle connexion. Même
      // canal que le `default`, mais déclaré explicitement (cf. commentaire
      // des constantes). Ajout purement additif : aucun type existant ne
      // change de canal.
      case weeklyDigestType:
      case newLoginType:
        return general;
      default:
        return general;
    }
  }

  /// Id 31-bit positif, requis par flutter_local_notifications.
  static int stableId(String seed) => seed.hashCode & 0x7fffffff;

  /// Clé de groupement Android (une pile par canal métier).
  static String androidGroupKey(String? type) =>
      'fimus_${androidChannelIdForType(type)}';
}
