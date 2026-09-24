import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/notification_preferences.dart';
import 'package:monitrack/services/notifications/reminder_ids.dart';
import 'package:monitrack/services/notifications/reminder_plan.dart';

/// Préférences par défaut + heures calmes 22:00 → 07:00 (plage à cheval sur
/// minuit, le cas le plus piégeux).
const _quietOvernight = NotificationPreferences(
  quietHoursEnabled: true,
  quietHoursStart: '22:00',
  quietHoursEnd: '07:00',
);

ReminderRequest _debt({
  String id = 'dette-1',
  DateTime? at,
  double amount = 1500,
  String? contactName = 'Awa',
}) =>
    ReminderRequest(
      kind: ReminderKind.debt,
      expenseId: id,
      title: 'Dette',
      amount: amount,
      currency: 'XOF',
      at: at ?? DateTime(2026, 10, 1),
      isDebt: true,
      contactName: contactName,
    );

ReminderRequest _scheduled({
  String id = 'dep-1',
  DateTime? at,
  double amount = 42,
}) =>
    ReminderRequest(
      kind: ReminderKind.scheduledExpense,
      expenseId: id,
      title: 'Loyer',
      amount: amount,
      currency: 'XOF',
      at: at ?? DateTime(2026, 10, 1, 9, 15),
    );

void main() {
  group('applyQuietHours — plage à cheval sur minuit (22:00 → 07:00)', () {
    test('un rappel à 23:00 bascule au lendemain 07:00', () {
      final result =
          applyQuietHours(DateTime(2026, 10, 1, 23), _quietOvernight);
      expect(result, DateTime(2026, 10, 2, 7));
    });

    test('un rappel à 06:00 est décalé au même jour 07:00', () {
      final result = applyQuietHours(DateTime(2026, 10, 1, 6), _quietOvernight);
      expect(result, DateTime(2026, 10, 1, 7));
    });

    test('minuit pile bascule au 07:00 du même jour civil', () {
      final result = applyQuietHours(DateTime(2026, 10, 2), _quietOvernight);
      expect(result, DateTime(2026, 10, 2, 7));
    });

    test('la borne de début (22:00) est incluse, la borne de fin (07:00) non',
        () {
      expect(
        applyQuietHours(DateTime(2026, 10, 1, 22), _quietOvernight),
        DateTime(2026, 10, 2, 7),
      );
      expect(
        applyQuietHours(DateTime(2026, 10, 1, 7), _quietOvernight),
        DateTime(2026, 10, 1, 7),
      );
    });

    test('un rappel hors plage (12:00) reste inchangé, minutes comprises', () {
      final when = DateTime(2026, 10, 1, 12, 34);
      expect(applyQuietHours(when, _quietOvernight), when);
    });

    test('le décalage est idempotent : réappliqué, il ne bouge plus', () {
      final once = applyQuietHours(DateTime(2026, 10, 1, 23), _quietOvernight);
      expect(applyQuietHours(once, _quietOvernight), once);
    });

    test('le passage de mois est correctement franchi', () {
      final result =
          applyQuietHours(DateTime(2026, 10, 31, 23, 30), _quietOvernight);
      expect(result, DateTime(2026, 11, 1, 7));
    });
  });

  group('applyQuietHours — autres configurations', () {
    test('plage non wrappante (13:00 → 15:00) : décalage le même jour', () {
      const prefs = NotificationPreferences(
        quietHoursEnabled: true,
        quietHoursStart: '13:00',
        quietHoursEnd: '15:00',
      );
      expect(
        applyQuietHours(DateTime(2026, 10, 1, 14), prefs),
        DateTime(2026, 10, 1, 15),
      );
      // Hors plage : inchangé, des deux côtés.
      final avant = DateTime(2026, 10, 1, 12, 59);
      final apres = DateTime(2026, 10, 1, 15, 1);
      expect(applyQuietHours(avant, prefs), avant);
      expect(applyQuietHours(apres, prefs), apres);
    });

    test('quiet_hours_enabled à false : aucune heure n\'est déplacée', () {
      const prefs = NotificationPreferences(
        quietHoursEnabled: false,
        quietHoursStart: '22:00',
        quietHoursEnd: '07:00',
      );
      final when = DateTime(2026, 10, 1, 23, 45);
      expect(applyQuietHours(when, prefs), when);
    });

    test('start == end : plage vide, rien n\'est déplacé', () {
      const prefs = NotificationPreferences(
        quietHoursEnabled: true,
        quietHoursStart: '22:00',
        quietHoursEnd: '22:00',
      );
      for (final heure in [0, 7, 12, 22, 23]) {
        final when = DateTime(2026, 10, 1, heure);
        expect(applyQuietHours(when, prefs), when, reason: '${heure}h');
      }
    });

    test('une plage illisible retombe sur les défauts 22:00 → 07:00', () {
      const prefs = NotificationPreferences(
        quietHoursEnabled: true,
        quietHoursStart: 'n\'importe quoi',
        quietHoursEnd: '99:99',
      );
      // `parseTime` retombe sur les valeurs par défaut du modèle.
      expect(prefs.quietStartTime, const TimeOfDay(hour: 22, minute: 0));
      expect(prefs.quietEndTime, const TimeOfDay(hour: 7, minute: 0));
      expect(
        applyQuietHours(DateTime(2026, 10, 1, 23), prefs),
        DateTime(2026, 10, 2, 7),
      );
    });
  });

  group('resolvePlannedReminder', () {
    final now = DateTime(2026, 9, 20, 10);

    test('une dette prend l\'heure de `reminder_hour`, pas celle de l\'échéance',
        () {
      const prefs = NotificationPreferences(reminderHour: '09:45');
      final planned = resolvePlannedReminder(
        request: _debt(at: DateTime(2026, 10, 1, 23, 59)),
        prefs: prefs,
        now: now,
      );
      expect(planned, isNotNull);
      expect(planned!.scheduledAt, DateTime(2026, 10, 1, 9, 45));
    });

    test('une dépense programmée conserve l\'heure choisie par l\'utilisateur',
        () {
      const prefs = NotificationPreferences(reminderHour: '09:45');
      final planned = resolvePlannedReminder(
        request: _scheduled(at: DateTime(2026, 10, 1, 18, 30)),
        prefs: prefs,
        now: now,
      );
      expect(planned!.scheduledAt, DateTime(2026, 10, 1, 18, 30));
    });

    test('notify_debts à false : aucune dette n\'est planifiée', () {
      const prefs = NotificationPreferences(notifyDebts: false);
      expect(
        resolvePlannedReminder(request: _debt(), prefs: prefs, now: now),
        isNull,
      );
      // L'interrupteur des dettes ne coupe pas les dépenses programmées.
      expect(
        resolvePlannedReminder(request: _scheduled(), prefs: prefs, now: now),
        isNotNull,
      );
    });

    test('notify_scheduled_expenses à false : aucune dépense n\'est planifiée',
        () {
      const prefs = NotificationPreferences(notifyScheduledExpenses: false);
      expect(
        resolvePlannedReminder(request: _scheduled(), prefs: prefs, now: now),
        isNull,
      );
      expect(
        resolvePlannedReminder(request: _debt(), prefs: prefs, now: now),
        isNotNull,
      );
    });

    test('une échéance déjà passée n\'est pas replanifiée', () {
      const prefs = NotificationPreferences();
      expect(
        resolvePlannedReminder(
          request: _debt(at: DateTime(2026, 9, 19)),
          prefs: prefs,
          now: now,
        ),
        isNull,
      );
    });

    test('un rappel tombant exactement sur `now` est considéré comme passé',
        () {
      const prefs = NotificationPreferences();
      expect(
        resolvePlannedReminder(
          request: _scheduled(at: now),
          prefs: prefs,
          now: now,
        ),
        isNull,
      );
      expect(
        resolvePlannedReminder(
          request: _scheduled(at: now.add(const Duration(minutes: 1))),
          prefs: prefs,
          now: now,
        ),
        isNotNull,
      );
    });

    test(
        'les heures calmes peuvent sauver un rappel qui, sinon, serait dans le '
        'passé', () {
      // Rappel prévu à 06:00 alors qu\'il est déjà 06:30 : sans heures calmes
      // il serait écarté ; décalé à 07:00 il reste planifiable.
      final maintenant = DateTime(2026, 10, 1, 6, 30);
      expect(
        resolvePlannedReminder(
          request: _scheduled(at: DateTime(2026, 10, 1, 6)),
          prefs: const NotificationPreferences(),
          now: maintenant,
        ),
        isNull,
      );
      final avecCalme = resolvePlannedReminder(
        request: _scheduled(at: DateTime(2026, 10, 1, 6)),
        prefs: _quietOvernight,
        now: maintenant,
      );
      expect(avecCalme, isNotNull);
      expect(avecCalme!.scheduledAt, DateTime(2026, 10, 1, 7));
    });

    test('l\'id et le payload du rappel résolu sont stables et typés', () {
      final planned = resolvePlannedReminder(
        request: _debt(at: DateTime(2026, 10, 1), amount: 1500),
        prefs: const NotificationPreferences(reminderHour: '08:30'),
        now: now,
      )!;
      expect(planned.id, ReminderIds.debtNotificationId('dette-1'));
      final payload = jsonDecode(planned.payload) as Map<String, dynamic>;
      expect(payload['type'], 'debt_due_date_reminder');
      expect(payload['expense_uuid'], 'dette-1');
      expect(payload['debt_tag'], 'Awa');
      expect(payload['source'], 'local');
      expect(payload['fp'], '2026-10-01T08:30|1500.00');
    });

    test('le payload d\'une dépense programmée ne porte pas de `debt_tag`', () {
      final planned = resolvePlannedReminder(
        request: _scheduled(at: DateTime(2026, 10, 1, 9, 15)),
        prefs: const NotificationPreferences(),
        now: now,
      )!;
      final payload = jsonDecode(planned.payload) as Map<String, dynamic>;
      expect(payload.containsKey('debt_tag'), isFalse);
      expect(payload['type'], 'scheduled_expense_due');
      expect(planned.id,
          ReminderIds.scheduledExpenseNotificationId('dep-1'));
    });
  });

  group('resolvePlannedReminders', () {
    final now = DateTime(2026, 9, 20, 10);

    test('déduplique par id : deux demandes pour la même dette → un rappel',
        () {
      final planned = resolvePlannedReminders(
        requests: [
          _debt(at: DateTime(2026, 10, 1), amount: 1000),
          _debt(at: DateTime(2026, 10, 5), amount: 2000),
        ],
        prefs: const NotificationPreferences(reminderHour: '08:30'),
        now: now,
      );
      expect(planned, hasLength(1));
      // La dernière demande gagne.
      expect(planned.single.scheduledAt, DateTime(2026, 10, 5, 8, 30));
    });

    test('une dette et une dépense programmée de même uuid coexistent', () {
      final planned = resolvePlannedReminders(
        requests: [
          _debt(id: 'uuid-partage'),
          _scheduled(id: 'uuid-partage'),
        ],
        prefs: const NotificationPreferences(),
        now: now,
      );
      expect(planned, hasLength(2));
      expect(planned.map((p) => p.id).toSet(), hasLength(2));
    });

    test('les demandes écartées ne figurent pas dans le résultat', () {
      final planned = resolvePlannedReminders(
        requests: [
          _debt(id: 'ok', at: DateTime(2026, 10, 1)),
          _debt(id: 'passe', at: DateTime(2026, 9, 1)),
        ],
        prefs: const NotificationPreferences(),
        now: now,
      );
      expect(planned.map((p) => p.expenseId), ['ok']);
    });

    test('liste vide en entrée → liste vide en sortie', () {
      expect(
        resolvePlannedReminders(
          requests: const [],
          prefs: const NotificationPreferences(),
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('reminderFingerprint', () {
    test('est stable à la minute : secondes et millisecondes sont ignorées',
        () {
      final a = reminderFingerprint(DateTime(2026, 10, 1, 8, 30), 1500);
      final b = reminderFingerprint(
        DateTime(2026, 10, 1, 8, 30, 59, 999),
        1500,
      );
      expect(a, b);
      expect(a, '2026-10-01T08:30|1500.00');
    });

    test('change si la minute change', () {
      expect(
        reminderFingerprint(DateTime(2026, 10, 1, 8, 30), 1500),
        isNot(reminderFingerprint(DateTime(2026, 10, 1, 8, 31), 1500)),
      );
    });

    test('change si le montant change, à deux décimales près', () {
      final base = reminderFingerprint(DateTime(2026, 10, 1, 8, 30), 1500);
      expect(
        reminderFingerprint(DateTime(2026, 10, 1, 8, 30), 1500.01),
        isNot(base),
      );
      // En deçà de la demi-centime, l'empreinte ne bouge pas.
      expect(
        reminderFingerprint(DateTime(2026, 10, 1, 8, 30), 1500.001),
        base,
      );
    });

    test('les composantes de date sont toujours sur deux chiffres', () {
      expect(
        reminderFingerprint(DateTime(2026, 1, 2, 3, 4), 5),
        '2026-01-02T03:04|5.00',
      );
    });
  });

  group('isManagedReminderPayload', () {
    test('reconnaît les deux familles de rappels locaux', () {
      expect(
        isManagedReminderPayload(buildReminderPayload(
          kind: ReminderKind.debt,
          expenseId: 'x',
          scheduledAt: DateTime(2026, 10, 1, 8),
          amount: 1,
        )),
        isTrue,
      );
      expect(
        isManagedReminderPayload(buildReminderPayload(
          kind: ReminderKind.scheduledExpense,
          expenseId: 'x',
          scheduledAt: DateTime(2026, 10, 1, 8),
          amount: 1,
        )),
        isTrue,
      );
    });

    test('ignore un payload nul, vide ou étranger', () {
      expect(isManagedReminderPayload(null), isFalse);
      expect(isManagedReminderPayload(''), isFalse);
      expect(
        isManagedReminderPayload('{"type":"mass_broadcast"}'),
        isFalse,
      );
      expect(
        isManagedReminderPayload('{"type":"new_debt","expense_uuid":"x"}'),
        isFalse,
      );
    });
  });

  group('computeReminderDiff — réconciliation idempotente', () {
    final now = DateTime(2026, 9, 20, 10);

    List<PlannedReminder> attendus() => resolvePlannedReminders(
          requests: [
            _debt(id: 'd1', at: DateTime(2026, 10, 1), amount: 1000),
            _scheduled(id: 's1', at: DateTime(2026, 10, 2, 9), amount: 50),
          ],
          prefs: const NotificationPreferences(),
          now: now,
        );

    List<PendingReminder> versPendings(List<PlannedReminder> planned) => [
          for (final p in planned) PendingReminder(p.id, p.payload),
        ];

    test('attendu == programmé → diff vide (rien n\'est retouché)', () {
      final expected = attendus();
      final diff = computeReminderDiff(
        expected: expected,
        pending: versPendings(expected),
      );
      expect(diff.toCancel, isEmpty);
      expect(diff.toSchedule, isEmpty);
      expect(diff.isEmpty, isTrue);
    });

    test('l\'idempotence tient sur deux passes consécutives', () {
      final expected = attendus();
      var pendings = <PendingReminder>[];
      // Première passe : tout est à poser.
      var diff = computeReminderDiff(expected: expected, pending: pendings);
      expect(diff.toSchedule, hasLength(2));
      // On applique le diff puis on rejoue : plus rien à faire.
      pendings = [
        for (final p in diff.toSchedule) PendingReminder(p.id, p.payload),
      ];
      diff = computeReminderDiff(expected: expected, pending: pendings);
      expect(diff.isEmpty, isTrue);
    });

    test('attendu vide → tous les rappels gérés passent en annulation', () {
      final pendings = versPendings(attendus());
      final diff = computeReminderDiff(expected: const [], pending: pendings);
      expect(diff.toCancel.toSet(), pendings.map((p) => p.id).toSet());
      expect(diff.toSchedule, isEmpty);
    });

    test(
        'empreinte changée → rappel replanifié sur le même id, sans annulation',
        () {
      final expected = attendus();
      final perime = [
        for (final p in expected)
          PendingReminder(
            p.id,
            buildReminderPayload(
              kind: p.kind,
              expenseId: p.expenseId,
              contactName: p.request.contactName,
              // Montant différent → empreinte différente.
              scheduledAt: p.scheduledAt,
              amount: p.request.amount + 1,
            ),
          ),
      ];
      final diff = computeReminderDiff(expected: expected, pending: perime);
      expect(diff.toCancel, isEmpty,
          reason: 'annuler créerait une fenêtre sans rappel');
      expect(diff.toSchedule.map((p) => p.id).toSet(),
          expected.map((p) => p.id).toSet());
    });

    test('une notification non gérée n\'est jamais annulée', () {
      final expected = attendus();
      final pendings = [
        ...versPendings(expected),
        const PendingReminder(999001, '{"type":"mass_broadcast"}'),
        const PendingReminder(999002, null),
        const PendingReminder(999003, 'payload opaque'),
      ];
      final diff = computeReminderDiff(expected: expected, pending: pendings);
      expect(diff.toCancel, isEmpty);
      expect(diff.toSchedule, isEmpty);
    });

    test(
        'même attendu vide, une notification non gérée survit à la '
        'réconciliation', () {
      final diff = computeReminderDiff(
        expected: const [],
        pending: const [
          PendingReminder(999001, '{"type":"mass_broadcast"}'),
          PendingReminder(999002, null),
        ],
      );
      expect(diff.toCancel, isEmpty);
      expect(diff.isEmpty, isTrue);
    });

    test('un rappel géré devenu inattendu est annulé, les autres conservés',
        () {
      final expected = attendus();
      final pendings = [
        ...versPendings(expected),
        PendingReminder(
          ReminderIds.debtNotificationId('dette-supprimee'),
          buildReminderPayload(
            kind: ReminderKind.debt,
            expenseId: 'dette-supprimee',
            scheduledAt: DateTime(2026, 10, 9, 8, 30),
            amount: 10,
          ),
        ),
      ];
      final diff = computeReminderDiff(expected: expected, pending: pendings);
      expect(diff.toCancel,
          [ReminderIds.debtNotificationId('dette-supprimee')]);
      expect(diff.toSchedule, isEmpty);
    });

    test('un rappel attendu absent du plugin est simplement posé', () {
      final expected = attendus();
      final diff = computeReminderDiff(
        expected: expected,
        pending: [versPendings(expected).first],
      );
      expect(diff.toCancel, isEmpty);
      expect(diff.toSchedule, hasLength(1));
      expect(diff.toSchedule.single.id, expected.last.id);
    });

    test('ReminderDiff.isEmpty ne vaut vrai que si les deux listes sont vides',
        () {
      const vide = ReminderDiff(toCancel: [], toSchedule: []);
      expect(vide.isEmpty, isTrue);
      const avecAnnulation = ReminderDiff(toCancel: [1], toSchedule: []);
      expect(avecAnnulation.isEmpty, isFalse);
    });
  });

  group('reminderTypeOf / applyTimeOfDay', () {
    test('chaque famille porte le type FCM attendu', () {
      expect(reminderTypeOf(ReminderKind.debt), 'debt_due_date_reminder');
      expect(
        reminderTypeOf(ReminderKind.scheduledExpense),
        'scheduled_expense_due',
      );
    });

    test('applyTimeOfDay remplace l\'heure sans toucher à la date', () {
      final result = applyTimeOfDay(
        const TimeOfDay(hour: 8, minute: 30),
        DateTime(2026, 10, 1, 23, 59, 59),
      );
      expect(result, DateTime(2026, 10, 1, 8, 30));
    });
  });
}
