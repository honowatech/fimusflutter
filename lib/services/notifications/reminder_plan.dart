import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../../models/notification_preferences.dart';
import '../../providers/notification_preferences_provider.dart';
import 'reminder_ids.dart';

/// Préférences de rappel utilisées par la planification.
///
/// Source unique : le blob JSON mis en cache sous la clé SharedPreferences
/// `NotificationPreferencesProvider.cacheKey`
/// (`'notification_preferences_cache'`), lu via la méthode **statique**
/// [NotificationPreferencesProvider.readCachedPreferences] — pas d'instance de
/// provider, pas de `BuildContext` : la planification reste utilisable hors
/// arbre de widgets.
///
/// Champs consommés ici : `notify_debts`, `notify_scheduled_expenses`,
/// `reminder_hour` (`"HH:mm"`, défaut `"08:30"`), `quiet_hours_enabled`
/// (défaut `false`), `quiet_hours_start` / `quiet_hours_end` (`"HH:mm"`,
/// défauts `"22:00"` / `"07:00"`). Cache absent (premier lancement, jamais
/// synchronisé) ou illisible → valeurs par défaut du modèle : mieux vaut un
/// rappel à 08:30 qu'aucun rappel.
Future<NotificationPreferences> loadReminderPreferences() async {
  try {
    final cached = await NotificationPreferencesProvider.readCachedPreferences();
    if (cached != null) return cached;
  } catch (e) {
    debugPrint('Error loading reminder preferences: $e');
  }
  return const NotificationPreferences();
}

/// Applique une heure du jour à la date de [day].
DateTime applyTimeOfDay(TimeOfDay time, DateTime day) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute);

/// Décale un rappel tombant dans les heures calmes vers la fin de la plage.
/// Hors heures calmes, [when] est retourné inchangé.
///
/// La détection de la plage (y compris à cheval sur minuit) est déléguée à
/// [NotificationPreferences.isWithinQuietHours] ; ici on ne calcule que la
/// date de sortie de plage.
DateTime applyQuietHours(DateTime when, NotificationPreferences prefs) {
  if (!prefs.isWithinQuietHours(when)) return when;
  final sameDay = applyTimeOfDay(prefs.quietEndTime, when);
  // Plage à cheval sur minuit et rappel avant minuit → la fin est le lendemain.
  if (!sameDay.isAfter(when)) {
    return applyTimeOfDay(prefs.quietEndTime, when.add(const Duration(days: 1)));
  }
  return sameDay;
}

/// Famille de rappel local.
enum ReminderKind {
  /// Échéance d'une dette / créance.
  debt,

  /// Rappel d'une dépense programmée.
  scheduledExpense,
}

/// Type FCM/payload associé à la famille.
String reminderTypeOf(ReminderKind kind) => kind == ReminderKind.debt
    ? 'debt_due_date_reminder'
    : 'scheduled_expense_due';

/// Demande de rappel telle que l'exprime le métier (date brute, non résolue).
@immutable
class ReminderRequest {
  const ReminderRequest({
    required this.kind,
    required this.expenseId,
    required this.title,
    required this.amount,
    required this.currency,
    required this.at,
    this.isDebt = false,
    this.contactName,
  });

  final ReminderKind kind;
  final String expenseId;
  final String title;
  final double amount;
  final String currency;

  /// Pour [ReminderKind.debt] : la date d'échéance (l'heure est imposée par les
  /// préférences). Pour [ReminderKind.scheduledExpense] : la date/heure de
  /// rappel choisie par l'utilisateur.
  final DateTime at;

  /// Dette (on doit) vs créance (on nous doit) — pour le texte affiché.
  final bool isDebt;
  final String? contactName;
}

/// Rappel résolu : heure finale calculée, id et payload stables.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.request,
    required this.scheduledAt,
  });

  final ReminderRequest request;
  final DateTime scheduledAt;

  ReminderKind get kind => request.kind;
  String get expenseId => request.expenseId;

  int get id => request.kind == ReminderKind.debt
      ? ReminderIds.debtNotificationId(request.expenseId)
      : ReminderIds.scheduledExpenseNotificationId(request.expenseId);

  String get payload => buildReminderPayload(
        kind: request.kind,
        expenseId: request.expenseId,
        contactName: request.contactName,
        scheduledAt: scheduledAt,
        amount: request.amount,
      );
}

/// Payload JSON d'un rappel local.
///
/// Contient une empreinte `fp` (heure planifiée + montant) : c'est elle qui
/// permet à la réconciliation de détecter qu'un rappel déjà programmé est
/// périmé (échéance déplacée, montant modifié) et doit être replanifié, sans
/// pour autant tout annuler à l'aveugle.
String buildReminderPayload({
  required ReminderKind kind,
  required String expenseId,
  required DateTime scheduledAt,
  required double amount,
  String? contactName,
}) {
  return jsonEncode({
    'type': reminderTypeOf(kind),
    'expense_uuid': expenseId,
    if (kind == ReminderKind.debt) 'debt_tag': contactName,
    'source': 'local',
    'fp': reminderFingerprint(scheduledAt, amount),
  });
}

/// Empreinte d'un rappel : heure planifiée (à la minute) + montant.
String reminderFingerprint(DateTime scheduledAt, double amount) {
  final local = scheduledAt.toLocal();
  final stamp = '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}T'
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '$stamp|${amount.toStringAsFixed(2)}';
}

/// Vrai si le payload appartient à un rappel local géré par l'application
/// (et donc susceptible d'être annulé par la réconciliation).
bool isManagedReminderPayload(String? payload) {
  if (payload == null) return false;
  return payload.contains('debt_due_date_reminder') ||
      payload.contains('scheduled_expense_due');
}

/// Résout une liste de demandes en rappels effectivement planifiables :
/// applique les interrupteurs, l'heure de rappel, les heures calmes, écarte
/// les échéances passées et déduplique par id.
///
/// Fonction pure : aucun accès au plugin, testable directement.
List<PlannedReminder> resolvePlannedReminders({
  required Iterable<ReminderRequest> requests,
  required NotificationPreferences prefs,
  required DateTime now,
}) {
  final byId = <int, PlannedReminder>{};
  for (final request in requests) {
    final planned = resolvePlannedReminder(
      request: request,
      prefs: prefs,
      now: now,
    );
    if (planned != null) byId[planned.id] = planned;
  }
  return byId.values.toList();
}

/// Résout une demande unique. Retourne `null` si le rappel ne doit pas exister
/// (famille désactivée, échéance déjà passée).
PlannedReminder? resolvePlannedReminder({
  required ReminderRequest request,
  required NotificationPreferences prefs,
  required DateTime now,
}) {
  if (request.kind == ReminderKind.debt && !prefs.notifyDebts) return null;
  if (request.kind == ReminderKind.scheduledExpense &&
      !prefs.notifyScheduledExpenses) {
    return null;
  }

  // Dette : seule la date compte, l'heure vient des préférences
  // (`reminder_hour`). Dépense programmée : l'heure choisie par l'utilisateur
  // est respectée.
  final base = request.kind == ReminderKind.debt
      ? applyTimeOfDay(prefs.reminderTime, request.at)
      : request.at;

  final scheduledAt = applyQuietHours(base, prefs);
  if (!scheduledAt.isAfter(now)) return null;

  return PlannedReminder(request: request, scheduledAt: scheduledAt);
}

/// Rappel déjà programmé côté plugin, réduit à ce dont le diff a besoin
/// (permet de tester le diff sans dépendre de `PendingNotificationRequest`).
@immutable
class PendingReminder {
  const PendingReminder(this.id, this.payload);

  final int id;
  final String? payload;
}

/// Résultat d'une réconciliation : ce qu'il faut annuler, ce qu'il faut poser.
@immutable
class ReminderDiff {
  const ReminderDiff({required this.toCancel, required this.toSchedule});

  final List<int> toCancel;
  final List<PlannedReminder> toSchedule;

  bool get isEmpty => toCancel.isEmpty && toSchedule.isEmpty;
}

/// Diff idempotent entre l'état attendu et l'état programmé.
///
/// - n'annule que les rappels **gérés par l'application** qui ne sont plus
///   attendus (ou dont l'empreinte a changé) ;
/// - ne planifie que les rappels attendus absents (ou périmés) ;
/// - ne touche à aucune autre notification programmée.
///
/// Fonction pure : testable sans plugin.
ReminderDiff computeReminderDiff({
  required List<PlannedReminder> expected,
  required List<PendingReminder> pending,
}) {
  final expectedById = <int, PlannedReminder>{
    for (final p in expected) p.id: p,
  };
  final pendingById = <int, PendingReminder>{};
  for (final p in pending) {
    if (isManagedReminderPayload(p.payload)) pendingById[p.id] = p;
  }

  // On n'annule que ce qui n'est plus attendu du tout : un rappel simplement
  // périmé est **remplacé** par une nouvelle planification sur le même id
  // (zonedSchedule écrase), ce qui évite la fenêtre pendant laquelle le rappel
  // n'existerait plus.
  final toCancel = <int>[
    for (final id in pendingById.keys)
      if (!expectedById.containsKey(id)) id,
  ];

  final toSchedule = <PlannedReminder>[];
  for (final entry in expectedById.entries) {
    final current = pendingById[entry.key];
    if (current == null || current.payload != entry.value.payload) {
      toSchedule.add(entry.value);
    }
  }

  return ReminderDiff(toCancel: toCancel, toSchedule: toSchedule);
}
