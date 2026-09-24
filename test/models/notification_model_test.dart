import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/notification_model.dart';
import 'package:monitrack/utils/notification_route.dart';

void main() {
  group('NotificationCategory.fromType', () {
    test('tous les types de dette tombent dans la catégorie dettes', () {
      for (final type in [
        'new_debt',
        'new_joint_debt',
        'debt_created',
        'debt_updated',
        'debt_rejected',
        'debt_due_date_reminder',
      ]) {
        expect(NotificationCategory.fromType(type), NotificationCategory.debts,
            reason: type);
      }
    });

    test('contacts, comptes conjoints et dépenses programmées', () {
      expect(NotificationCategory.fromType('contact_added'),
          NotificationCategory.contacts);
      expect(NotificationCategory.fromType('joint_account_added'),
          NotificationCategory.jointAccounts);
      expect(NotificationCategory.fromType('scheduled_expense_due'),
          NotificationCategory.scheduledExpenses);
    });

    test('mass_broadcast et announcements mènent tous deux aux annonces', () {
      expect(NotificationCategory.fromType('mass_broadcast'),
          NotificationCategory.announcements);
      expect(NotificationCategory.fromType('announcements'),
          NotificationCategory.announcements);
    });

    test('type nul, vide ou inconnu → other', () {
      expect(NotificationCategory.fromType(null), NotificationCategory.other);
      expect(NotificationCategory.fromType(''), NotificationCategory.other);
      expect(NotificationCategory.fromType('type_du_futur'),
          NotificationCategory.other);
    });

    test('la casse n\'est pas normalisée : un type mal casé retombe sur other',
        () {
      // Documente le contrat réel : le backend envoie des types en minuscules.
      expect(NotificationCategory.fromType('New_Debt'),
          NotificationCategory.other);
    });

    test('`data[type]` prime sur le type Laravel dans le modèle', () {
      final n = NotificationModel(
        id: '1',
        type: 'App\\Notifications\\Whatever',
        data: const {'type': 'contact_added'},
      );
      expect(n.category, NotificationCategory.contacts);
    });

    test('sans `data[type]`, le type Laravel sert de repli', () {
      final n = NotificationModel(
        id: '1',
        type: 'mass_broadcast',
        data: const {},
      );
      expect(n.category, NotificationCategory.announcements);
    });
  });

  group('NotificationDateBucket.of', () {
    final now = DateTime(2026, 10, 15, 14, 30);

    test('aujourd\'hui, même en début de journée', () {
      expect(NotificationDateBucket.of(now, now: now),
          NotificationDateBucket.today);
      expect(
        NotificationDateBucket.of(DateTime(2026, 10, 15, 0, 1), now: now),
        NotificationDateBucket.today,
      );
    });

    test('hier, y compris à 23:59', () {
      expect(
        NotificationDateBucket.of(DateTime(2026, 10, 14, 23, 59), now: now),
        NotificationDateBucket.yesterday,
      );
      expect(
        NotificationDateBucket.of(DateTime(2026, 10, 14), now: now),
        NotificationDateBucket.yesterday,
      );
    });

    test('de 2 à 7 jours → cette semaine', () {
      for (var jours = 2; jours <= 7; jours++) {
        expect(
          NotificationDateBucket.of(
            now.subtract(Duration(days: jours)),
            now: now,
          ),
          NotificationDateBucket.thisWeek,
          reason: 'il y a $jours jours',
        );
      }
    });

    test('la bascule se fait au 8e jour', () {
      expect(
        NotificationDateBucket.of(DateTime(2026, 10, 8), now: now),
        NotificationDateBucket.thisWeek,
      );
      expect(
        NotificationDateBucket.of(DateTime(2026, 10, 7), now: now),
        NotificationDateBucket.earlier,
      );
    });

    test('une date future (horloge décalée) est traitée comme aujourd\'hui',
        () {
      expect(
        NotificationDateBucket.of(DateTime(2026, 10, 16, 3), now: now),
        NotificationDateBucket.today,
      );
      expect(
        NotificationDateBucket.of(DateTime(2027, 1, 1), now: now),
        NotificationDateBucket.today,
      );
    });

    test('une date absente est reléguée en fin de liste, jamais perdue', () {
      expect(NotificationDateBucket.of(null, now: now),
          NotificationDateBucket.earlier);
    });

    test('le découpage se fait sur le jour civil, pas sur 24 h glissantes', () {
      // 23h d'écart, mais deux jours civils différents.
      final minuitPasse = DateTime(2026, 10, 15, 0, 30);
      expect(
        NotificationDateBucket.of(DateTime(2026, 10, 14, 23, 30),
            now: minuitPasse),
        NotificationDateBucket.yesterday,
      );
    });
  });

  group('NotificationModel.fromPush', () {
    test('avec `notification_id` : l\'entrée porte l\'id serveur et agit', () {
      final push = {
        'type': 'new_debt',
        'expense_uuid': 'exp-1',
        'notification_id': 'srv-123',
        'title': 'Nouvelle dette',
      };
      final n = NotificationModel.fromPush(
        push,
        dedupeKey: NotificationRoute.dedupeKey(push),
      );
      expect(n.id, 'srv-123');
      expect(n.isPlaceholder, isFalse);
      expect(n.type, 'new_debt');
      expect(n.title, 'Nouvelle dette');
      expect(n.isRead, isFalse);
    });

    test('sans `notification_id` : placeholder local inerte préfixé `push_`',
        () {
      final push = {'type': 'new_debt', 'expense_uuid': 'exp-1'};
      final n = NotificationModel.fromPush(
        push,
        dedupeKey: NotificationRoute.dedupeKey(push),
      );
      expect(n.isPlaceholder, isTrue);
      expect(n.id, 'push_new_debt|exp-1');
      expect(n.dedupeKey, 'new_debt|exp-1');
    });

    test('un `notification_id` vide ou blanc retombe sur le placeholder', () {
      for (final valeur in ['', '   ']) {
        final push = {
          'type': 'new_debt',
          'expense_uuid': 'exp-1',
          'notification_id': valeur,
        };
        final n = NotificationModel.fromPush(
          push,
          dedupeKey: NotificationRoute.dedupeKey(push),
        );
        expect(n.isPlaceholder, isTrue, reason: '"$valeur"');
      }
    });

    test('un `notification_id` numérique est accepté tel quel', () {
      final n = NotificationModel.fromPush(
        {'type': 'new_debt', 'notification_id': 42},
        dedupeKey: 'new_debt|',
      );
      expect(n.id, '42');
      expect(n.isPlaceholder, isFalse);
    });

    test('createdAt est renseigné en UTC ISO 8601 et relisible en local', () {
      final n = NotificationModel.fromPush(
        const {'type': 'contact_added'},
        dedupeKey: 'contact_added|',
      );
      expect(n.createdAt, isNotNull);
      expect(DateTime.tryParse(n.createdAt!), isNotNull);
      expect(n.createdAt, endsWith('Z'));
      expect(n.createdAtLocal, isNotNull);
    });

    test('le `data` est copié : muter la source ne modifie pas le modèle', () {
      final push = <String, dynamic>{'type': 'contact_added', 'title': 'A'};
      final n = NotificationModel.fromPush(push, dedupeKey: 'contact_added|');
      push['title'] = 'B';
      expect(n.title, 'A');
    });
  });

  group('NotificationModel.dedupeKey', () {
    test('une ligne serveur retrouve la clé du placeholder issu du push', () {
      final push = {'type': 'joint_account_added', 'account_uuid': 'acc-7'};
      final placeholder = NotificationModel.fromPush(
        push,
        dedupeKey: NotificationRoute.dedupeKey(push),
      );
      final serveur = NotificationModel(
        id: 'srv-9',
        data: Map<String, dynamic>.from(push),
      );
      expect(placeholder.dedupeKey, serveur.dedupeKey);
      expect(serveur.dedupeKey, 'joint_account_added|acc-7');
    });

    test('un placeholder sans entité relit la clé encapsulée dans son id', () {
      final push = {'type': 'mass_broadcast'};
      final placeholder = NotificationModel.fromPush(
        push,
        dedupeKey: NotificationRoute.dedupeKey(push),
      );
      expect(placeholder.id, 'push_mass_broadcast|');
      expect(placeholder.dedupeKey, 'mass_broadcast|');
    });

    test('une ligne serveur sans entité se replie sur son propre id', () {
      final n = NotificationModel(id: 'srv-1', data: const {'type': 'x'});
      expect(n.dedupeKey, 'x|srv-1');
    });

    test('l\'ordre de priorité des entités suit NotificationRoute', () {
      final data = <String, dynamic>{
        'type': 'new_debt',
        'expense_uuid': 'exp',
        'account_uuid': 'acc',
        'campaign_id': 'camp',
      };
      final n = NotificationModel(id: 'srv', data: data);
      expect(n.dedupeKey, 'new_debt|exp');
      expect(n.dedupeKey, NotificationRoute.dedupeKey(data));
    });

    test('une entité présente mais vide n\'écrase pas le repli', () {
      final n = NotificationModel(
        id: 'srv-1',
        data: const {'type': 'new_debt', 'expense_uuid': ''},
      );
      expect(n.dedupeKey, 'new_debt|srv-1');
    });
  });

  group('NotificationModel — champs dérivés', () {
    test('le message retombe sur `body` puis sur le titre', () {
      expect(
        NotificationModel(id: '1', data: const {'message': 'M'}).message,
        'M',
      );
      expect(
        NotificationModel(id: '1', data: const {'body': 'B'}).message,
        'B',
      );
      expect(
        NotificationModel(id: '1', data: const {'title': 'T'}).message,
        'T',
      );
      expect(NotificationModel(id: '1', data: const {}).message, '');
    });

    test('copyWith(clearReadAt) est le seul moyen de repasser en non-lu', () {
      final lue = NotificationModel(
        id: '1',
        data: const {},
        readAt: '2026-10-01T08:00:00Z',
      );
      expect(lue.isRead, isTrue);
      // Passer `null` ne change rien (contrat documenté).
      expect(lue.copyWith(readAt: null).isRead, isTrue);
      expect(lue.copyWith(clearReadAt: true).isRead, isFalse);
    });

    test('createdAtLocal tolère une date absente ou illisible', () {
      expect(NotificationModel(id: '1', data: const {}).createdAtLocal, isNull);
      expect(
        NotificationModel(id: '1', data: const {}, createdAt: '').createdAtLocal,
        isNull,
      );
      expect(
        NotificationModel(id: '1', data: const {}, createdAt: 'hier')
            .createdAtLocal,
        isNull,
      );
      expect(
        NotificationModel(
          id: '1',
          data: const {},
          createdAt: '2026-10-01T08:00:00Z',
        ).createdAtLocal,
        isNotNull,
      );
    });

    test('aller-retour base de données : data JSON préservé', () {
      final n = NotificationModel(
        id: 'srv-1',
        type: 'new_debt',
        data: const {'type': 'new_debt', 'expense_uuid': 'exp-1', 'amount': 12},
        createdAt: '2026-10-01T08:00:00Z',
      );
      final relu = NotificationModel.fromDbMap(n.toDbMap());
      expect(relu.id, n.id);
      expect(relu.type, n.type);
      expect(relu.data, n.data);
      expect(relu.dedupeKey, n.dedupeKey);
    });

    test('fromDbMap survit à un `data` corrompu', () {
      final relu = NotificationModel.fromDbMap(const {
        'id': 'srv-1',
        'data': '{ceci n\'est pas du json',
      });
      expect(relu.id, 'srv-1');
      expect(relu.data, isEmpty);
      expect(relu.category, NotificationCategory.other);
    });
  });
}
