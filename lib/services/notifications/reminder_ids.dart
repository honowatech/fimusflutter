import '../../utils/notification_channels.dart';

/// Calculs purs des rappels locaux (testables sans plugin).
class ReminderIds {
  /// Heure par défaut des rappels de dette. L'heure effective vient du champ
  /// `reminder_hour` des préférences de notification (voir
  /// `loadReminderPreferences` dans `reminder_plan.dart`) ; ces constantes ne
  /// servent plus que de référence historique.
  static const debtHour = 8;
  static const debtMinute = 30;

  static DateTime debtWallClock(DateTime dueDate) => DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        debtHour,
        debtMinute,
      );

  static bool isInThePast(DateTime scheduled, DateTime now) =>
      !scheduled.isAfter(now);

  /// Graine d'id d'un rappel d'échéance de dette.
  ///
  /// Préfixée : sans préfixe, la graine valait l'uuid nu, or l'affichage d'un
  /// push métier (`new_debt`, `debt_updated`…) retombe sur `expense_uuid`
  /// comme graine. Les deux ids se seraient alors confondus et un push aurait
  /// remplacé — voire supprimé sur iOS — le rappel local encore programmé pour
  /// la même dette.
  static String debtIdSeed(String expenseId) => 'debt_$expenseId';

  static int debtNotificationId(String expenseId) =>
      NotificationChannels.stableId(debtIdSeed(expenseId));

  static int scheduledExpenseNotificationId(String expenseId) =>
      NotificationChannels.stableId(scheduledIdSeed(expenseId));

  static String scheduledIdSeed(String expenseId) => 'scheduled_$expenseId';
}
