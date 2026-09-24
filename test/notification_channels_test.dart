import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:monitrack/services/notifications/local_notification_settings.dart';
import 'package:monitrack/services/notifications/notification_texts.dart';
import 'package:monitrack/utils/notification_channels.dart';

void main() {
  group('NotificationChannels.androidChannelIdForType', () {
    test('mappe les types dettes vers le canal v3 dettes', () {
      for (final type in [
        'new_debt',
        'debt_updated',
        'debt_rejected',
        'new_joint_debt',
        'debt_created',
        'debt_due_date_reminder',
      ]) {
        expect(
          NotificationChannels.androidChannelIdForType(type),
          NotificationChannels.debts,
          reason: type,
        );
      }
    });

    test('mappe contacts, comptes conjoints et dépenses programmées', () {
      expect(
        NotificationChannels.androidChannelIdForType('contact_added'),
        NotificationChannels.contacts,
      );
      expect(
        NotificationChannels.androidChannelIdForType('joint_account_added'),
        NotificationChannels.jointAccounts,
      );
      expect(
        NotificationChannels.androidChannelIdForType('scheduled_expense_due'),
        NotificationChannels.scheduledExpenses,
      );
    });

    test('mass_broadcast va sur le canal annonces, pas sur le canal général',
        () {
      expect(
        NotificationChannels.androidChannelIdForType('mass_broadcast'),
        NotificationChannels.announcements,
      );
      expect(
        NotificationChannels.androidChannelIdForType('mass_broadcast'),
        isNot(NotificationChannels.general),
      );
    });

    test('repli sur le canal général pour un type nul ou inconnu', () {
      expect(
        NotificationChannels.androidChannelIdForType(null),
        NotificationChannels.general,
      );
      expect(
        NotificationChannels.androidChannelIdForType(''),
        NotificationChannels.general,
      );
      expect(
        NotificationChannels.androidChannelIdForType('type_du_futur'),
        NotificationChannels.general,
      );
    });
  });

  group('NotificationChannels.stableId', () {
    test('est toujours positif et 31-bit', () {
      final id = NotificationChannels.stableId('expense-uuid-1');
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7fffffff));
    });

    test('androidGroupKey préfixe le canal', () {
      expect(
        NotificationChannels.androidGroupKey('new_joint_debt'),
        'fimus_${NotificationChannels.debts}',
      );
    });

    test('androidGroupKey sépare les annonces des notifications de service',
        () {
      expect(
        NotificationChannels.androidGroupKey('mass_broadcast'),
        isNot(NotificationChannels.androidGroupKey('new_debt')),
      );
      expect(
        NotificationChannels.androidGroupKey('mass_broadcast'),
        'fimus_${NotificationChannels.announcements}',
      );
    });

    test('est déterministe', () {
      expect(
        NotificationChannels.stableId('abc'),
        NotificationChannels.stableId('abc'),
      );
    });
  });

  group('Cohérence des listes de canaux', () {
    test('`all` déclare chaque canal v3 une seule fois', () {
      expect(
        NotificationChannels.all.toSet().length,
        NotificationChannels.all.length,
        reason: 'un canal déclaré deux fois serait créé deux fois',
      );
      expect(
        NotificationChannels.all,
        containsAll(<String>[
          NotificationChannels.debts,
          NotificationChannels.scheduledExpenses,
          NotificationChannels.contacts,
          NotificationChannels.jointAccounts,
          NotificationChannels.general,
          NotificationChannels.announcements,
        ]),
      );
      for (final id in NotificationChannels.all) {
        expect(id, startsWith('fimus_'), reason: id);
        expect(id, contains('_v3'),
            reason: '$id doit porter la génération de canal v3');
      }
    });

    test('aucun canal actif ne figure dans la liste des canaux obsolètes', () {
      for (final id in NotificationChannels.all) {
        expect(NotificationChannels.legacy, isNot(contains(id)), reason: id);
      }
      expect(NotificationChannels.legacy.toSet().length,
          NotificationChannels.legacy.length);
    });

    test('tout type connu est routé vers un canal déclaré dans `all`', () {
      const types = [
        'new_debt',
        'debt_updated',
        'debt_rejected',
        'new_joint_debt',
        'debt_created',
        'debt_due_date_reminder',
        'contact_added',
        'joint_account_added',
        'scheduled_expense_due',
        'mass_broadcast',
        NotificationChannels.budgetThresholdType,
        NotificationChannels.lowBalanceType,
        NotificationChannels.unsyncedDataType,
        null,
      ];
      for (final type in types) {
        expect(
          NotificationChannels.all,
          contains(NotificationChannels.androidChannelIdForType(type)),
          reason: '$type',
        );
      }
    });
  });

  group('Alertes locales (canal ajouté au sprint 4)', () {
    test('les trois types d\'alerte locale vont sur le canal alertes', () {
      for (final type in [
        NotificationChannels.budgetThresholdType,
        NotificationChannels.lowBalanceType,
        NotificationChannels.unsyncedDataType,
      ]) {
        expect(
          NotificationChannels.androidChannelIdForType(type),
          NotificationChannels.alerts,
          reason: type,
        );
      }
    });

    test('l\'ajout des alertes ne déplace aucun type existant', () {
      expect(NotificationChannels.androidChannelIdForType('new_debt'),
          NotificationChannels.debts);
      expect(NotificationChannels.androidChannelIdForType('mass_broadcast'),
          NotificationChannels.announcements);
      expect(
        NotificationChannels.androidChannelIdForType('scheduled_expense_due'),
        NotificationChannels.scheduledExpenses,
      );
      expect(NotificationChannels.androidChannelIdForType(null),
          NotificationChannels.general);
    });

    test('une alerte est actionnable : importance haute, avec son', () {
      expect(androidImportanceForChannel(NotificationChannels.alerts),
          Importance.high);
      expect(androidPriorityForChannel(NotificationChannels.alerts),
          Priority.high);
      expect(androidPlaySoundForChannel(NotificationChannels.alerts), isTrue);
    });

    test('les alertes ont leur propre pile de groupement', () {
      expect(
        NotificationChannels.androidGroupKey(
            NotificationChannels.lowBalanceType),
        'fimus_${NotificationChannels.alerts}',
      );
      expect(
        NotificationChannels.androidGroupKey(
            NotificationChannels.lowBalanceType),
        isNot(NotificationChannels.androidGroupKey('new_debt')),
      );
    });
  });

  group('Hiérarchie d\'importance des canaux', () {
    test('une dette prime sur une dépense programmée, qui prime sur le reste',
        () {
      expect(androidImportanceForChannel(NotificationChannels.debts),
          Importance.max);
      expect(
        androidImportanceForChannel(NotificationChannels.scheduledExpenses),
        Importance.high,
      );
      for (final id in [
        NotificationChannels.contacts,
        NotificationChannels.jointAccounts,
        NotificationChannels.general,
      ]) {
        expect(androidImportanceForChannel(id), Importance.defaultImportance,
            reason: id);
      }
    });

    test('les annonces sont discrètes : importance basse et aucun son', () {
      expect(
        androidImportanceForChannel(NotificationChannels.announcements),
        Importance.low,
      );
      expect(
        androidPriorityForChannel(NotificationChannels.announcements),
        Priority.low,
      );
      expect(
        androidPlaySoundForChannel(NotificationChannels.announcements),
        isFalse,
      );
    });

    test('tous les autres canaux sonnent', () {
      for (final id in NotificationChannels.all) {
        if (id == NotificationChannels.announcements) continue;
        expect(androidPlaySoundForChannel(id), isTrue, reason: id);
      }
    });

    test('un identifiant inconnu retombe sur l\'importance par défaut', () {
      expect(androidImportanceForChannel('canal_inexistant'),
          Importance.defaultImportance);
      expect(androidPriorityForChannel('canal_inexistant'),
          Priority.defaultPriority);
      expect(androidPlaySoundForChannel('canal_inexistant'), isTrue);
    });

    test('la priorité est alignée sur l\'importance de chaque canal', () {
      expect(androidPriorityForChannel(NotificationChannels.debts),
          Priority.high);
      expect(androidPriorityForChannel(NotificationChannels.scheduledExpenses),
          Priority.high);
      expect(androidPriorityForChannel(NotificationChannels.general),
          Priority.defaultPriority);
    });
  });

  group('androidChannelSpec', () {
    late AppLocalizations fr;
    late AppLocalizations en;

    setUp(() {
      fr = NotificationTexts.forLocaleCode('fr');
      en = NotificationTexts.forLocaleCode('en');
    });

    test('libelle le canal annonces en français et en anglais', () {
      final specFr = androidChannelSpec(NotificationChannels.announcements, fr);
      final specEn = androidChannelSpec(NotificationChannels.announcements, en);

      expect(specFr.id, NotificationChannels.announcements);
      expect(specFr.name, 'Annonces');
      expect(specEn.name, 'Announcements');
      expect(specFr.name, isNot(specEn.name));
      expect(specFr.description, isNotEmpty);
      expect(specEn.description, isNotEmpty);
    });

    test('un identifiant inconnu retombe sur le canal Général (id ET libellé)',
        () {
      final spec = androidChannelSpec('fimus_general_v2', fr);
      expect(spec.id, NotificationChannels.general);
      expect(spec.name, fr.notifChannelGeneralName);
      expect(spec.importance, Importance.defaultImportance);
      expect(spec.playSound, isTrue);
    });

    test('un canal obsolète ne conserve jamais son ancien identifiant', () {
      for (final legacyId in NotificationChannels.legacy) {
        expect(androidChannelSpec(legacyId, fr).id, NotificationChannels.general,
            reason: legacyId);
      }
    });

    test('la vibration suit le son (annonces muettes et sans vibration)', () {
      final annonces = androidChannelSpec(NotificationChannels.announcements, fr);
      expect(annonces.playSound, isFalse);
      expect(annonces.vibrate, isFalse);

      final dettes = androidChannelSpec(NotificationChannels.debts, fr);
      expect(dettes.playSound, isTrue);
      expect(dettes.vibrate, isTrue);
    });

    test('chaque canal a des libellés distincts et non vides', () {
      final specs = androidChannelSpecs(fr);
      expect(specs.length, NotificationChannels.all.length);
      expect(specs.map((s) => s.id).toList(), NotificationChannels.all);

      final names = specs.map((s) => s.name).toSet();
      expect(names.length, specs.length,
          reason: 'deux canaux partagent le même libellé visible');
      for (final spec in specs) {
        expect(spec.name, isNotEmpty, reason: spec.id);
        expect(spec.description, isNotEmpty, reason: spec.id);
      }
    });

    test('toChannel reporte importance et son sur le canal Android', () {
      final channel =
          androidChannelSpec(NotificationChannels.announcements, fr).toChannel();
      expect(channel.id, NotificationChannels.announcements);
      expect(channel.importance, Importance.low);
      expect(channel.playSound, isFalse);
      expect(channel.enableVibration, isFalse);
    });
  });
}
