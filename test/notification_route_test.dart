import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/notification_model.dart';
import 'package:monitrack/utils/notification_route.dart';

void main() {
  group('NotificationRoute.fromData', () {
    test('contact_added → contacts', () {
      final route = NotificationRoute.fromData({'type': 'contact_added'});
      expect(route.target, NotificationTarget.contacts);
      expect(route.expenseId, isNull);
    });

    test('scheduled_expense_due conserve l\'id', () {
      final route = NotificationRoute.fromData({
        'type': 'scheduled_expense_due',
        'expense_uuid': 'exp-1',
      });
      expect(route.target, NotificationTarget.scheduledExpense);
      expect(route.expenseId, 'exp-1');
    });

    test('types dette → debt', () {
      for (final type in [
        'new_debt',
        'new_joint_debt',
        'debt_created',
        'debt_updated',
        'debt_rejected',
        'debt_due_date_reminder',
      ]) {
        final route = NotificationRoute.fromData({
          'type': type,
          'expense_uuid': 'e1',
          'debt_tag': 'Jean',
        });
        expect(route.target, NotificationTarget.debt, reason: type);
        expect(route.debtTag, 'Jean');
        expect(route.expenseId, 'e1');
      }
    });

    test('joint_account_added transporte l\'uuid du compte, pas la dépense',
        () {
      final route = NotificationRoute.fromData({
        'type': 'joint_account_added',
        'account_uuid': 'acc-9',
        'expense_uuid': 'exp-parasite',
      });
      expect(route.target, NotificationTarget.jointAccount);
      expect(route.accountUuid, 'acc-9');
      expect(route.expenseId, isNull);
    });

    test('mass_broadcast → broadcast et conserve `campaign_id`', () {
      final route = NotificationRoute.fromData({
        'type': 'mass_broadcast',
        'campaign_id': 'camp-2026-10',
      });
      expect(route.target, NotificationTarget.broadcast);
      expect(route.campaignId, 'camp-2026-10');
    });

    test('mass_broadcast sans campagne : campaignId nul, cible conservée', () {
      final route = NotificationRoute.fromData({'type': 'mass_broadcast'});
      expect(route.target, NotificationTarget.broadcast);
      expect(route.campaignId, isNull);
    });

    test('un campaign_id numérique est normalisé en chaîne', () {
      final route = NotificationRoute.fromData({
        'type': 'mass_broadcast',
        'campaign_id': 42,
      });
      expect(route.campaignId, '42');
    });

    test('`campaign_id` n\'est conservé que pour les annonces', () {
      final route = NotificationRoute.fromData({
        'type': 'contact_added',
        'campaign_id': 'camp-1',
      });
      expect(route.campaignId, isNull);
    });

    test('l\'id de dépense accepte les alias expense_id et id', () {
      expect(
        NotificationRoute.fromData({
          'type': 'scheduled_expense_due',
          'expense_id': 'alias-1',
        }).expenseId,
        'alias-1',
      );
      expect(
        NotificationRoute.fromData({
          'type': 'scheduled_expense_due',
          'id': 'alias-2',
        }).expenseId,
        'alias-2',
      );
      // `expense_uuid` reste prioritaire sur les alias.
      expect(
        NotificationRoute.fromData({
          'type': 'scheduled_expense_due',
          'expense_uuid': 'uuid',
          'expense_id': 'alias-1',
          'id': 'alias-2',
        }).expenseId,
        'uuid',
      );
    });

    test('type absent ou inconnu → unknown', () {
      expect(
        NotificationRoute.fromData(const {}).target,
        NotificationTarget.unknown,
      );
      expect(
        NotificationRoute.fromData({'type': 'type_du_futur'}).target,
        NotificationTarget.unknown,
      );
    });
  });

  group('NotificationRoute.dedupeKey / NotificationModel.dedupeKey', () {
    test('même type + uuid → même clé', () {
      final a = {'type': 'new_joint_debt', 'expense_uuid': 'abc'};
      final b = NotificationModel(id: 'server-1', data: {
        'type': 'new_joint_debt',
        'expense_uuid': 'abc',
        'message': 'x',
      });
      expect(NotificationRoute.dedupeKey(a), b.dedupeKey);
    });

    test('une annonce se dédoublonne par campagne', () {
      final push = {'type': 'mass_broadcast', 'campaign_id': 'camp-1'};
      expect(NotificationRoute.dedupeKey(push), 'mass_broadcast|camp-1');
      final ligneServeur = NotificationModel(
        id: 'srv-77',
        data: Map<String, dynamic>.from(push),
      );
      expect(ligneServeur.dedupeKey, NotificationRoute.dedupeKey(push));
    });

    test('deux campagnes distinctes ne se confondent pas', () {
      expect(
        NotificationRoute.dedupeKey(
            {'type': 'mass_broadcast', 'campaign_id': 'a'}),
        isNot(NotificationRoute.dedupeKey(
            {'type': 'mass_broadcast', 'campaign_id': 'b'})),
      );
    });

    test('sans entité connue, la clé garde le type et reste stable', () {
      final key = NotificationRoute.dedupeKey({'type': 'contact_added'});
      expect(key, 'contact_added|');
      expect(NotificationRoute.dedupeKey({'type': 'contact_added'}), key);
    });

    test('un type absent ne fait pas planter la clé', () {
      expect(NotificationRoute.dedupeKey(const {}), '|');
    });
  });
}
