import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/services/notifications/notification_texts.dart';

void main() {
  // Champ statique global : chaque test repart de la langue de repli pour ne
  // pas dépendre de l'ordre d'exécution.
  setUp(() {
    NotificationTexts.localeCode = NotificationTexts.fallbackLocaleCode;
  });

  group('NotificationTexts.resolveLocaleCode', () {
    test('accepte les langues réellement supportées', () {
      expect(NotificationTexts.resolveLocaleCode('fr'), 'fr');
      expect(NotificationTexts.resolveLocaleCode('en'), 'en');
    });

    test('normalise la casse et les variantes régionales', () {
      expect(NotificationTexts.resolveLocaleCode('EN'), 'en');
      expect(NotificationTexts.resolveLocaleCode('en_US'), 'en');
      expect(NotificationTexts.resolveLocaleCode('EN-gb'), 'en');
      expect(NotificationTexts.resolveLocaleCode('fr_CI'), 'fr');
      expect(NotificationTexts.resolveLocaleCode('  fr-FR  '), 'fr');
    });

    test('retombe sur le français pour une valeur absente, vide ou inconnue',
        () {
      expect(NotificationTexts.resolveLocaleCode(null), 'fr');
      expect(NotificationTexts.resolveLocaleCode(''), 'fr');
      expect(NotificationTexts.resolveLocaleCode('   '), 'fr');
      expect(NotificationTexts.resolveLocaleCode('de'), 'fr');
      expect(NotificationTexts.resolveLocaleCode('zz_ZZ'), 'fr');
      expect(NotificationTexts.resolveLocaleCode('_'), 'fr');
    });
  });

  group('NotificationTexts.forLocaleCode', () {
    test('sert les textes de la langue demandée', () {
      expect(NotificationTexts.forLocaleCode('fr').notifChannelGeneralName,
          'Général');
      expect(NotificationTexts.forLocaleCode('en').notifChannelGeneralName,
          'General');
    });

    test('une locale inconnue sert les textes français, sans lever', () {
      final textes = NotificationTexts.forLocaleCode('kl_KL');
      expect(textes.localeName, 'fr');
      expect(textes.unnamedContact, 'Un contact');
    });

    test('`current` suit `setLocale` puis revient au repli', () {
      NotificationTexts.setLocale(const Locale('en'));
      expect(NotificationTexts.localeCode, 'en');
      expect(NotificationTexts.current.scheduledConfirmAction, 'Confirm');

      // Une locale non supportée ramène la langue de repli.
      NotificationTexts.setLocale(const Locale('de'));
      expect(NotificationTexts.localeCode, 'fr');
      expect(NotificationTexts.current.scheduledConfirmAction, 'Confirmer');
    });

    test('textes FR par défaut', () {
      final t = NotificationTexts.current;
      expect(t.scheduledExpenseNotifTitle, contains('Dépense programmée'));
      expect(t.debtDueNotifTitleDebt, contains('Dette'));
      expect(t.unnamedContact, 'Un contact');
    });

    test('textes EN après setLocale', () {
      NotificationTexts.setLocale(const Locale('en'));
      final t = NotificationTexts.current;
      expect(t.scheduledConfirmAction, 'Confirm');
      expect(t.debtDueNotifTitleReceivable.toLowerCase(),
          contains('receivable'));
    });
  });

  group('NotificationTexts.formatAmount', () {
    test('sépare les milliers par une espace', () {
      expect(NotificationTexts.formatAmount(1500000), '1 500 000');
      expect(NotificationTexts.formatAmount(1500), '1 500');
      expect(NotificationTexts.formatAmount(999), '999');
      expect(NotificationTexts.formatAmount(0), '0');
    });

    test('n\'affiche les décimales que si elles existent', () {
      expect(NotificationTexts.formatAmount(1500000.25), '1 500 000.25');
      expect(NotificationTexts.formatAmount(1500.5), '1 500.50');
      // Un double « rond » ne doit pas devenir « 1 500.00 ».
      expect(NotificationTexts.formatAmount(1500.0), '1 500');
      expect(NotificationTexts.formatAmount(1500.0), isNot(contains('.')));
    });

    test('le seuil de bascule est le demi-centime', () {
      // En deçà : arrondi à l'entier, pas de décimales affichées.
      expect(NotificationTexts.formatAmount(1500.004), '1 500');
      // Au-delà : affichage à deux décimales.
      expect(NotificationTexts.formatAmount(1500.006), '1 500.01');
    });

    test('préserve le signe des montants négatifs', () {
      expect(NotificationTexts.formatAmount(-1500), '-1 500');
      expect(NotificationTexts.formatAmount(-1500.25), '-1 500.25');
    });

    test('gère un montant à sept chiffres sans perdre de groupe', () {
      expect(NotificationTexts.formatAmount(1234567), '1 234 567');
      expect(NotificationTexts.formatAmount(12345678), '12 345 678');
    });
  });

  group('NotificationTexts.formatTime', () {
    test('formate en 24 h avec zéros de tête', () {
      expect(NotificationTexts.formatTime(DateTime(2026, 10, 1, 8, 5)), '08:05');
      expect(NotificationTexts.formatTime(DateTime(2026, 10, 1, 0, 0)), '00:00');
      expect(
          NotificationTexts.formatTime(DateTime(2026, 10, 1, 23, 59)), '23:59');
    });

    test('n\'utilise jamais le format 12 h, quelle que soit la langue', () {
      NotificationTexts.setLocale(const Locale('en'));
      final texte = NotificationTexts.formatTime(DateTime(2026, 10, 1, 13, 7));
      expect(texte, '13:07');
      expect(texte.toUpperCase(), isNot(contains('PM')));
    });

    test('ignore les secondes', () {
      expect(
        NotificationTexts.formatTime(DateTime(2026, 10, 1, 8, 30, 59)),
        '08:30',
      );
    });
  });
}
