import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../utils/notification_channels.dart';
import 'local_notification_settings.dart';
import 'notification_texts.dart';
import 'reminder_ids.dart';
import 'reminder_plan.dart';

class ReminderScheduler {
  ReminderScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool isReady = false;

  /// Fenêtre anti-rebond : deux réconciliations rapprochées (démarrage +
  /// première synchronisation, par exemple) n'en déclenchent qu'une.
  static const reconcileDebounce = Duration(seconds: 5);

  DateTime? _lastReconcileAt;
  Future<void>? _reconcileInFlight;

  Future<AndroidScheduleMode> resolveAndroidScheduleMode() async {
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null &&
          (await androidPlugin.canScheduleExactNotifications() ?? false)) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
      debugPrint('Exact alarms not permitted, falling back to inexact alarms');
    } catch (e) {
      debugPrint('Error checking exact alarm permission: $e');
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  // --- Réconciliation idempotente (N18) -------------------------------------

  /// Aligne les rappels locaux sur l'état attendu, sans table rase.
  ///
  /// [requests] décrit l'ensemble des rappels attendus (dépenses programmées
  /// ET échéances de dettes non soldées). On lit les notifications déjà
  /// programmées, on n'annule que celles qui ne sont plus attendues et on ne
  /// (re)planifie que celles qui manquent ou dont l'empreinte a changé.
  ///
  /// Protégée contre les appels concurrents (un seul passage à la fois) et
  /// anti-rebond ([reconcileDebounce]) sauf si [force].
  Future<void> reconcile(
    List<ReminderRequest> requests, {
    bool force = false,
  }) {
    if (!isReady) {
      debugPrint('ReminderScheduler not ready, skipping reconcile');
      return Future.value();
    }
    final inFlight = _reconcileInFlight;
    if (inFlight != null) return inFlight;

    final last = _lastReconcileAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < reconcileDebounce) {
      return Future.value();
    }

    final future = _runReconcile(requests).whenComplete(() {
      _lastReconcileAt = DateTime.now();
      _reconcileInFlight = null;
    });
    _reconcileInFlight = future;
    return future;
  }

  Future<void> _runReconcile(List<ReminderRequest> requests) async {
    try {
      final prefs = await loadReminderPreferences();
      final expected = resolvePlannedReminders(
        requests: requests,
        prefs: prefs,
        now: DateTime.now(),
      );

      final pending = await _plugin.pendingNotificationRequests();
      final diff = computeReminderDiff(
        expected: expected,
        pending: [
          for (final request in pending)
            PendingReminder(request.id, request.payload),
        ],
      );
      if (diff.isEmpty) return;

      for (final id in diff.toCancel) {
        await _plugin.cancel(id: id);
      }
      if (diff.toSchedule.isNotEmpty) {
        // Résolu une seule fois pour tout le lot (appel plateforme).
        final mode = await resolveAndroidScheduleMode();
        for (final planned in diff.toSchedule) {
          await _schedule(planned, mode);
        }
      }
      debugPrint('Reminders reconciled: '
          '${diff.toCancel.length} cancelled, '
          '${diff.toSchedule.length} scheduled, '
          '${expected.length} expected');
    } catch (e) {
      debugPrint('Error reconciling reminders: $e');
    }
  }

  // --- Planification unitaire ------------------------------------------------

  Future<void> scheduleDebtDueDateReminder({
    required String expenseId,
    required double amount,
    required String currency,
    required DateTime dueDate,
    required bool isDebt,
    String? contactName,
  }) {
    return _scheduleOne(ReminderRequest(
      kind: ReminderKind.debt,
      expenseId: expenseId,
      title: contactName ?? '',
      amount: amount,
      currency: currency,
      at: dueDate,
      isDebt: isDebt,
      contactName: contactName,
    ));
  }

  Future<void> scheduleScheduledExpenseReminder({
    required String expenseId,
    required String title,
    required double amount,
    required String currency,
    required DateTime reminderAt,
  }) {
    return _scheduleOne(ReminderRequest(
      kind: ReminderKind.scheduledExpense,
      expenseId: expenseId,
      title: title,
      amount: amount,
      currency: currency,
      at: reminderAt,
    ));
  }

  /// Planifie une demande unique en passant par la même résolution que la
  /// réconciliation (préférences, heures calmes, échéance passée) : les
  /// empreintes de payload restent ainsi cohérentes entre les deux chemins.
  /// Si la demande n'est plus planifiable, l'éventuel rappel existant est
  /// annulé (interrupteur désactivé, échéance repassée dans le passé).
  Future<void> _scheduleOne(ReminderRequest request) async {
    try {
      if (!isReady) {
        debugPrint('ReminderScheduler not ready, skipping reminder');
        return;
      }
      final prefs = await loadReminderPreferences();
      final planned = resolvePlannedReminder(
        request: request,
        prefs: prefs,
        now: DateTime.now(),
      );
      if (planned == null) {
        await _cancelId(request.kind == ReminderKind.debt
            ? ReminderIds.debtNotificationId(request.expenseId)
            : ReminderIds.scheduledExpenseNotificationId(request.expenseId));
        return;
      }
      await _schedule(planned, await resolveAndroidScheduleMode());
    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  Future<void> _schedule(
      PlannedReminder planned, AndroidScheduleMode mode) async {
    final scheduledDate = tz.TZDateTime.from(planned.scheduledAt, tz.local);
    if (ReminderIds.isInThePast(scheduledDate, tz.TZDateTime.now(tz.local))) {
      return;
    }
    if (planned.kind == ReminderKind.debt) {
      await _scheduleDebt(planned, scheduledDate, mode);
    } else {
      await _scheduleExpense(planned, scheduledDate, mode);
    }
  }

  Future<void> _scheduleDebt(
    PlannedReminder planned,
    tz.TZDateTime scheduledDate,
    AndroidScheduleMode mode,
  ) async {
    try {
      final request = planned.request;
      final texts = NotificationTexts.current;
      final contactName = request.contactName;
      final labelContact = (contactName != null && contactName.isNotEmpty)
          ? contactName
          : texts.unnamedContact;
      // N14 : montant avec séparateur de milliers (lib/utils/formatters.dart)
      // et devise transmise par l'appelant (celle du profil / de l'opération).
      final amountLabel = NotificationTexts.formatAmount(request.amount);
      final notifTitle = request.isDebt
          ? texts.debtDueNotifTitleDebt
          : texts.debtDueNotifTitleReceivable;
      final notifBody = request.isDebt
          ? texts.debtDueNotifBodyDebt(
              amountLabel, request.currency, labelContact)
          : texts.debtDueNotifBodyReceivable(
              amountLabel, request.currency, labelContact);
      final spec = androidChannelSpec(NotificationChannels.debts, texts);

      await _plugin.zonedSchedule(
        id: planned.id,
        title: notifTitle,
        body: notifBody,
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            spec.id,
            spec.name,
            channelDescription: spec.description,
            importance: spec.importance,
            priority: spec.priority,
            playSound: spec.playSound,
            enableVibration: spec.vibrate,
            icon: statusNotificationIcon,
            groupKey: NotificationChannels.debts,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: mode,
        payload: planned.payload,
      );
    } catch (e) {
      debugPrint('Error scheduling debt due date reminder: $e');
    }
  }

  Future<void> _scheduleExpense(
    PlannedReminder planned,
    tz.TZDateTime scheduledDate,
    AndroidScheduleMode mode,
  ) async {
    try {
      final request = planned.request;
      final texts = NotificationTexts.current;
      final timeLabel = NotificationTexts.formatTime(planned.scheduledAt);
      final amountLabel = NotificationTexts.formatAmount(request.amount);
      final spec =
          androidChannelSpec(NotificationChannels.scheduledExpenses, texts);

      await _plugin.zonedSchedule(
        id: planned.id,
        title: texts.scheduledExpenseNotifTitle,
        body: texts.scheduledExpenseNotifBody(
            request.title, amountLabel, request.currency, timeLabel),
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            spec.id,
            spec.name,
            channelDescription: spec.description,
            importance: spec.importance,
            priority: spec.priority,
            playSound: spec.playSound,
            enableVibration: spec.vibrate,
            icon: statusNotificationIcon,
            groupKey: NotificationChannels.scheduledExpenses,
            actions: [
              AndroidNotificationAction(
                'scheduled_confirm',
                texts.scheduledConfirmAction,
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                'scheduled_cancel',
                texts.scheduledCancelAction,
                showsUserInterface: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            categoryIdentifier: scheduledCategoryId,
          ),
        ),
        androidScheduleMode: mode,
        payload: planned.payload,
      );
    } catch (e) {
      debugPrint('Error scheduling scheduled expense reminder: $e');
    }
  }

  // --- Annulations -----------------------------------------------------------

  Future<void> cancelDebtDueDateReminder(String expenseId) =>
      _cancelId(ReminderIds.debtNotificationId(expenseId));

  Future<void> cancelScheduledExpenseReminder(String expenseId) =>
      _cancelId(ReminderIds.scheduledExpenseNotificationId(expenseId));

  Future<void> _cancelId(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Error cancelling reminder $id: $e');
    }
  }

  Future<void> cancelAllByPayloadContains(String needle) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        final payload = request.payload;
        if (payload != null && payload.contains(needle)) {
          await _plugin.cancel(id: request.id);
        }
      }
    } catch (e) {
      debugPrint('Error cancelling reminders ($needle): $e');
    }
  }
}
