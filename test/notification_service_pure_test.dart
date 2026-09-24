import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/services/notification_service.dart';

/// Fonctions **pures** de `notification_service.dart` : contrat `suppress_local`
/// et traces de débogage. Aucun canal de plateforme n'est touché ici.
void main() {
  group('shouldSuppressLocalReminder', () {
    Map<String, dynamic> base({
      Object? suppress = 'true',
      Object? type = 'debt_due_date_reminder',
      Object? uuid = 'dette-1',
    }) =>
        <String, dynamic>{
          'suppress_local': ?suppress,
          'type': ?type,
          'expense_uuid': ?uuid,
        };

    test('suppress_local="true" + bon type + uuid → annulation demandée', () {
      expect(shouldSuppressLocalReminder(base()), isTrue);
    });

    test('la valeur est comparée sans tenir compte de la casse', () {
      expect(shouldSuppressLocalReminder(base(suppress: 'TRUE')), isTrue);
      expect(shouldSuppressLocalReminder(base(suppress: 'True')), isTrue);
    });

    test('un booléen JSON non textuel est accepté (toString → "true")', () {
      expect(shouldSuppressLocalReminder(base(suppress: true)), isTrue);
      expect(shouldSuppressLocalReminder(base(suppress: false)), isFalse);
    });

    test('suppress_local="false" → aucune annulation', () {
      expect(shouldSuppressLocalReminder(base(suppress: 'false')), isFalse);
    });

    test('suppress_local absent → aucune annulation', () {
      expect(shouldSuppressLocalReminder(base(suppress: null)), isFalse);
    });

    test('un autre type que le rappel d\'échéance n\'annule jamais rien', () {
      for (final type in [
        'new_debt',
        'debt_updated',
        'scheduled_expense_due',
        'mass_broadcast',
      ]) {
        expect(shouldSuppressLocalReminder(base(type: type)), isFalse,
            reason: type);
      }
    });

    test('type absent → aucune annulation', () {
      expect(shouldSuppressLocalReminder(base(type: null)), isFalse);
    });

    test('uuid absent ou vide → aucune annulation (on n\'annule pas à l\'aveugle)',
        () {
      expect(shouldSuppressLocalReminder(base(uuid: null)), isFalse);
      expect(shouldSuppressLocalReminder(base(uuid: '')), isFalse);
    });

    test('un payload vide ne lève pas', () {
      expect(shouldSuppressLocalReminder(const {}), isFalse);
    });
  });

  group('describeNotification — aucune fuite de donnée financière', () {
    test('ne reprend que le type et un identifiant', () {
      final trace = describeNotification({
        'type': 'new_debt',
        'expense_uuid': 'exp-77',
        'title': 'Dette de Awa Diallo',
        'body': 'Vous devez 1 500 000 XOF',
        'amount': 1500000,
        'contact_name': 'Awa Diallo',
      });
      expect(trace, 'type=new_debt id=exp-77');
      expect(trace, isNot(contains('1 500 000')));
      expect(trace, isNot(contains('1500000')));
      expect(trace, isNot(contains('Awa')));
      expect(trace.toLowerCase(), isNot(contains('dette de')));
    });

    test('`id` prime sur `expense_uuid`, qui prime sur `account_uuid`', () {
      expect(
        describeNotification({'type': 't', 'id': 'A', 'expense_uuid': 'B'}),
        'type=t id=A',
      );
      expect(
        describeNotification(
            {'type': 't', 'expense_uuid': 'B', 'account_uuid': 'C'}),
        'type=t id=B',
      );
      expect(
        describeNotification({'type': 't', 'account_uuid': 'C'}),
        'type=t id=C',
      );
    });

    test('data nul ou sans identifiant → trace neutre', () {
      expect(describeNotification(null), 'type=? id=?');
      expect(describeNotification(const {}), 'type=? id=?');
      expect(
        describeNotification({'title': 'Secret', 'amount': 42}),
        'type=? id=?',
      );
    });
  });

  group('describeNotificationPayload', () {
    test('décode un payload de rappel local sans exposer le montant', () {
      final payload = jsonEncode({
        'type': 'debt_due_date_reminder',
        'expense_uuid': 'exp-9',
        'debt_tag': 'Awa Diallo',
        'source': 'local',
        'fp': '2026-10-01T08:30|1500000.00',
      });
      final trace = describeNotificationPayload(payload);
      expect(trace, 'type=debt_due_date_reminder id=exp-9');
      expect(trace, isNot(contains('1500000')));
      expect(trace, isNot(contains('Awa')));
    });

    test('payload nul, illisible ou non-objet → trace neutre', () {
      expect(describeNotificationPayload(null), 'type=? id=?');
      expect(describeNotificationPayload('pas du json'), 'type=? id=?');
      expect(describeNotificationPayload('[1,2,3]'), 'type=? id=?');
      expect(describeNotificationPayload('"chaine"'), 'type=? id=?');
      expect(describeNotificationPayload(''), 'type=? id=?');
    });

    test('est cohérent avec describeNotification sur la même donnée', () {
      final data = {'type': 'contact_added', 'id': 'c-1', 'title': 'Privé'};
      expect(
        describeNotificationPayload(jsonEncode(data)),
        describeNotification(data),
      );
    });
  });
}
