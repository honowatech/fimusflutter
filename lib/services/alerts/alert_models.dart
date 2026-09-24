import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../utils/notification_channels.dart';

/// Famille d'une alerte locale.
enum LocalAlertKind { budgetThreshold, lowBalance, unsyncedData }

/// Type FCM/payload d'une famille d'alerte. Miroir du mapping
/// `NotificationChannels.androidChannelIdForType`. Fonction pure.
String localAlertTypeOf(LocalAlertKind kind) => switch (kind) {
      LocalAlertKind.budgetThreshold => NotificationChannels.budgetThresholdType,
      LocalAlertKind.lowBalance => NotificationChannels.lowBalanceType,
      LocalAlertKind.unsyncedData => NotificationChannels.unsyncedDataType,
    };

/// Alerte locale retenue par l'évaluation, prête à être affichée.
///
/// Objet **pur** : il ne porte que des données (identité, montants), jamais de
/// texte traduit — la mise en mots est faite par `AlertTexts`, la mise à
/// l'écran par `LocalAlertsService`.
@immutable
sealed class PendingAlert {
  const PendingAlert();

  LocalAlertKind get kind;

  /// Graine d'identifiant de notification. Stable : une alerte qui se répète
  /// (après désarmement puis réarmement) **remplace** la précédente dans le
  /// tiroir au lieu de s'empiler.
  String get idSeed;

  /// Données complémentaires du payload JSON (hors `type` et `source`).
  Map<String, dynamic> get payloadData;

  String get notificationType => localAlertTypeOf(kind);

  /// Identifiant 31 bits attendu par flutter_local_notifications.
  int get notificationId => NotificationChannels.stableId(idSeed);

  /// Payload transporté par la notification. `source: 'local_alert'` permet de
  /// distinguer ces alertes des rappels planifiés (`source: 'local'`) et des
  /// pushs serveur.
  String get payload => jsonEncode({
        'type': notificationType,
        'source': 'local_alert',
        ...payloadData,
      });
}

/// Palier de budget atteint pour une catégorie sur le mois en cours.
@immutable
final class BudgetThresholdAlert extends PendingAlert {
  const BudgetThresholdAlert({
    required this.category,
    required this.period,
    required this.tier,
    required this.spent,
    required this.budget,
    required this.currency,
  });

  /// Catégorie normalisée (`normalizeCategory`).
  final String category;

  /// Période mensuelle `"AAAA-MM"` (`AlertEmissionState.periodKey`).
  final String period;

  /// Palier franchi : 80 ou 100.
  final int tier;

  /// Total dépensé sur la catégorie pour le mois en cours.
  final double spent;

  /// Budget mensuel configuré.
  final double budget;

  final String currency;

  /// Pourcentage réellement consommé, arrondi à l'entier (peut dépasser 100).
  int get consumedPercent =>
      budget <= 0 ? 0 : (spent / budget * 100).round();

  @override
  LocalAlertKind get kind => LocalAlertKind.budgetThreshold;

  /// Une seule notification par (mois, catégorie) : l'alerte « 100 % »
  /// remplace l'alerte « 80 % » encore affichée.
  @override
  String get idSeed => 'alert_budget_${period}_$category';

  @override
  Map<String, dynamic> get payloadData => {
        'category': category,
        'period': period,
        'tier': tier,
      };
}

/// Solde d'un compte passé sous son seuil.
@immutable
final class LowBalanceAlert extends PendingAlert {
  const LowBalanceAlert({
    required this.accountId,
    required this.accountName,
    required this.balance,
    required this.threshold,
    required this.currency,
  });

  final String accountId;
  final String accountName;
  final double balance;
  final double threshold;
  final String currency;

  @override
  LocalAlertKind get kind => LocalAlertKind.lowBalance;

  @override
  String get idSeed => 'alert_low_balance_$accountId';

  @override
  Map<String, dynamic> get payloadData => {'account_id': accountId};
}

/// Opérations en attente d'envoi depuis trop longtemps.
@immutable
final class UnsyncedDataAlert extends PendingAlert {
  const UnsyncedDataAlert({
    required this.pendingCount,
    required this.pendingSinceHours,
  });

  /// Nombre de lignes locales encore marquées `is_synced = 0`.
  final int pendingCount;

  /// Ancienneté de la plus ancienne de ces lignes, en heures.
  final int pendingSinceHours;

  @override
  LocalAlertKind get kind => LocalAlertKind.unsyncedData;

  /// Alerte unique : une nouvelle émission remplace la précédente.
  @override
  String get idSeed => 'alert_unsynced_data';

  @override
  Map<String, dynamic> get payloadData => {
        'pending_count': pendingCount,
        'pending_since_hours': pendingSinceHours,
      };
}

/// Photographie des données locales encore en attente d'envoi.
///
/// Produite par `UnsyncedProbe` (accès SQLite en lecture seule) et consommée
/// par l'évaluateur, qui reste ainsi **pur** : un test fabrique directement un
/// [UnsyncedSnapshot] sans base de données.
@immutable
class UnsyncedSnapshot {
  const UnsyncedSnapshot({required this.pendingCount, this.oldestPendingAt});

  const UnsyncedSnapshot.empty() : pendingCount = 0, oldestPendingAt = null;

  final int pendingCount;

  /// Horodatage de la plus ancienne ligne en attente. `null` quand il est
  /// inconnu (lignes anciennes sans `updated_at` ni `created_at`) : on ne peut
  /// alors pas prouver l'ancienneté, donc on n'alerte pas.
  final DateTime? oldestPendingAt;

  bool get isEmpty => pendingCount <= 0;

  /// Agrège les photographies table par table. Fonction pure.
  static UnsyncedSnapshot combine(Iterable<UnsyncedSnapshot> parts) {
    var count = 0;
    DateTime? oldest;
    for (final part in parts) {
      count += part.pendingCount;
      final candidate = part.oldestPendingAt;
      if (candidate == null) continue;
      if (oldest == null || candidate.isBefore(oldest)) oldest = candidate;
    }
    return UnsyncedSnapshot(pendingCount: count, oldestPendingAt: oldest);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnsyncedSnapshot &&
          other.pendingCount == pendingCount &&
          other.oldestPendingAt == oldestPendingAt;

  @override
  int get hashCode => Object.hash(pendingCount, oldestPendingAt);
}
