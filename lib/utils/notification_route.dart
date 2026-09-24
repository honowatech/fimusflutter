import 'notification_channels.dart';

/// Cible de navigation issue d'un payload de notification (FCM, locale, inbox).
enum NotificationTarget {
  contacts,
  scheduledExpense,
  jointAccount,
  debt,
  broadcast,

  /// Bilan hebdomadaire (`weekly_digest`, sprint 5) : le contenu porte sur les
  /// dépenses de la semaine, l'onglet Dépenses est donc la destination utile.
  weeklyDigest,

  /// Alerte de sécurité « nouvelle connexion » (`new_login`, sprint 5). Porte
  /// l'action « Ce n'était pas moi » ([securityAction] /
  /// [NotificationRoute.actionEndpoint]).
  securityAlert,

  unknown,
}

/// Action de sécurité transportée par le payload `new_login`.
const String revokeOtherSessionsAction = 'revoke_other_sessions';

/// Repli si le serveur n'envoie pas `action_endpoint` (chemin figé dans
/// `Backend/config/notifications.php`).
const String revokeOtherSessionsEndpoint = '/api/security/revoke-other-sessions';

class NotificationRoute {
  final NotificationTarget target;
  final String? expenseId;
  final String? debtTag;
  final String? accountUuid;

  /// Campagne d'origine d'une annonce (`mass_broadcast`) : conservée pour la
  /// cible [NotificationTarget.broadcast], utile dès qu'un écran d'annonce
  /// dédié existera (aujourd'hui les annonces vivent dans le carrousel de
  /// l'accueil, alimenté par `AnnouncementService`).
  final String? campaignId;

  /// --- Champs propres à [NotificationTarget.securityAlert] ---------------

  /// Action proposée par le serveur (`action`), p. ex.
  /// [revokeOtherSessionsAction]. Nulle pour toutes les autres cibles.
  final String? securityAction;

  /// Libellé du bouton d'action fourni par le serveur (`action_label`), déjà
  /// traduit côté backend selon la locale du compte.
  final String? actionLabel;

  /// Chemin d'API à appeler (`action_endpoint`). Transmis par le serveur pour
  /// que l'application n'ait pas à figer la route.
  final String? actionEndpoint;

  /// Identifiant de l'appareil **qui vient de se connecter** (celui décrit par
  /// l'alerte), à ne pas confondre avec l'identifiant local.
  final String? deviceId;

  /// Libellé lisible de cet appareil (`device_label`) et lieu approximatif de
  /// la connexion (`location`), affichés dans la confirmation.
  final String? deviceLabel;
  final String? location;

  const NotificationRoute({
    required this.target,
    this.expenseId,
    this.debtTag,
    this.accountUuid,
    this.campaignId,
    this.securityAction,
    this.actionLabel,
    this.actionEndpoint,
    this.deviceId,
    this.deviceLabel,
    this.location,
  });

  static const _debtTypes = {
    'new_joint_debt',
    'debt_updated',
    'debt_created',
    'new_debt',
    'debt_rejected',
    'debt_due_date_reminder',
  };

  factory NotificationRoute.fromData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final expenseId =
        (data['expense_uuid'] ?? data['expense_id'] ?? data['id'])?.toString();
    final debtTag = data['debt_tag']?.toString();
    final accountUuid = data['account_uuid']?.toString();

    if (type == 'contact_added') {
      return const NotificationRoute(target: NotificationTarget.contacts);
    }
    if (type == 'scheduled_expense_due') {
      return NotificationRoute(
        target: NotificationTarget.scheduledExpense,
        expenseId: expenseId,
      );
    }
    if (type == 'joint_account_added') {
      return NotificationRoute(
        target: NotificationTarget.jointAccount,
        accountUuid: accountUuid,
      );
    }
    if (_debtTypes.contains(type)) {
      return NotificationRoute(
        target: NotificationTarget.debt,
        expenseId: expenseId,
        debtTag: debtTag,
      );
    }
    if (type == 'mass_broadcast') {
      return NotificationRoute(
        target: NotificationTarget.broadcast,
        campaignId: data['campaign_id']?.toString(),
      );
    }
    // Sprint 5. Le bilan hebdomadaire parle des dépenses de la semaine : le
    // renvoyer sur la route par défaut (boîte de réception) ferait perdre le
    // seul écran qui le prolonge.
    if (type == NotificationChannels.weeklyDigestType) {
      return const NotificationRoute(target: NotificationTarget.weeklyDigest);
    }
    if (type == NotificationChannels.newLoginType) {
      return NotificationRoute(
        target: NotificationTarget.securityAlert,
        securityAction: _nonEmpty(data['action']),
        actionLabel: _nonEmpty(data['action_label']),
        actionEndpoint: _nonEmpty(data['action_endpoint']) ??
            revokeOtherSessionsEndpoint,
        deviceId: _nonEmpty(data['device_id']),
        deviceLabel: _nonEmpty(data['device_label']),
        location: _nonEmpty(data['location']),
      );
    }
    return const NotificationRoute(target: NotificationTarget.unknown);
  }

  /// `true` si cette route porte l'action « Ce n'était pas moi » exploitable.
  bool get canRevokeOtherSessions =>
      target == NotificationTarget.securityAlert &&
      securityAction == revokeOtherSessionsAction;

  /// Le canal FCM caste toutes les valeurs en chaîne : un champ absent arrive
  /// donc sous la forme d'une chaîne vide, qu'il faut traiter comme nulle.
  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  /// Clé de dédoublonnage inbox (push optimiste vs ligne Laravel).
  static String dedupeKey(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final entity = entityFor(data) ?? '';
    return '$type|$entity';
  }

  /// Entité portée par un payload, servant de clé de dédoublonnage.
  ///
  /// `new_login` et `weekly_digest` ne désignent aucune opération ni aucun
  /// compte : sans les champs qui leur sont propres, deux alertes successives
  /// du même type partageraient la clé « type| » et s'écraseraient dans la
  /// boîte de réception.
  static String? entityFor(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == NotificationChannels.newLoginType) {
      final device = _nonEmpty(data['device_id']) ?? '';
      final at = _nonEmpty(data['logged_in_at']) ?? '';
      if (device.isNotEmpty || at.isNotEmpty) return '$device@$at';
    }
    if (type == NotificationChannels.weeklyDigestType) {
      final week = _nonEmpty(data['week_start']);
      if (week != null) return week;
    }
    return _nonEmpty(data['expense_uuid']) ??
        _nonEmpty(data['account_uuid']) ??
        _nonEmpty(data['campaign_id']) ??
        _nonEmpty(data['added_by_user_id']) ??
        _nonEmpty(data['id']);
  }
}
