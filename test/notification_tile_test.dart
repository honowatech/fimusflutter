import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:monitrack/models/notification_model.dart';
import 'package:monitrack/widgets/notification_tile.dart';

/// Instant de référence partagé par toute la liste (injecté par l'écran).
final _maintenant = DateTime(2026, 10, 15, 12);

NotificationModel _notif({
  String id = 'srv-1',
  String type = 'new_debt',
  String titre = 'Nouvelle dette',
  String message = 'Awa vous a ajouté une dette',
  DateTime? creeLe,
  bool lue = false,
}) =>
    NotificationModel(
      id: id,
      data: {'type': type, 'title': titre, 'message': message},
      readAt: lue ? '2026-10-15T11:00:00Z' : null,
      createdAt: (creeLe ?? _maintenant).toIso8601String(),
    );

Future<void> _pomper(
  WidgetTester tester,
  NotificationModel notification, {
  double echelleTexte = 1.0,
  double largeur = 360,
  bool modeSelection = false,
  bool selectionne = false,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(echelleTexte),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: largeur,
                // Comme dans le centre de notifications : la tuile est posée
                // dans une liste, sa hauteur est donc intrinsèque.
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    NotificationTile(
                      notification: notification,
                      isSelectionMode: modeSelection,
                      isSelected: selectionne,
                      onTap: onTap ?? () {},
                      onLongPress: onLongPress ?? () {},
                      now: _maintenant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('NotificationDateLabel.relative — libellés relatifs', () {
    late AppLocalizations fr;

    setUpAll(() async {
      // Hors arbre de widgets, les symboles de date d'`intl` ne sont pas
      // chargés : `GlobalMaterialLocalizations` s'en charge dans les tests de
      // widget, il faut le faire explicitement ici.
      await initializeDateFormatting('fr');
      fr = await AppLocalizations.delegate.load(const Locale('fr'));
    });

    String libelle(DateTime? date) => NotificationDateLabel.relative(
          date,
          now: _maintenant,
          locale: 'fr',
          l10n: fr,
        );

    test('moins d\'une minute → « À l\'instant »', () {
      expect(libelle(_maintenant), 'À l\'instant');
      expect(
        libelle(_maintenant.subtract(const Duration(seconds: 59))),
        'À l\'instant',
      );
    });

    test('une horloge serveur en avance ne produit jamais de négatif', () {
      expect(
        libelle(_maintenant.add(const Duration(minutes: 30))),
        'À l\'instant',
      );
    });

    test('de 1 à 59 minutes → minutes', () {
      expect(libelle(_maintenant.subtract(const Duration(minutes: 1))),
          'il y a 1 min');
      expect(libelle(_maintenant.subtract(const Duration(minutes: 12))),
          'il y a 12 min');
      expect(libelle(_maintenant.subtract(const Duration(minutes: 59))),
          'il y a 59 min');
    });

    test('de 1 à 23 heures → heures', () {
      expect(libelle(_maintenant.subtract(const Duration(minutes: 60))),
          'il y a 1 h');
      expect(libelle(_maintenant.subtract(const Duration(hours: 3))),
          'il y a 3 h');
      expect(libelle(_maintenant.subtract(const Duration(hours: 23, minutes: 59))),
          'il y a 23 h');
    });

    test('au-delà de 24 h → date courte sans l\'année (année en cours)', () {
      final date = _maintenant.subtract(const Duration(days: 5));
      final texte = libelle(date);
      expect(texte, DateFormat.MMMd('fr').format(date));
      expect(texte, isNot(contains('2026')));
      expect(texte, isNot(contains('il y a')));
    });

    test('une année différente → date complète avec l\'année', () {
      final date = DateTime(2025, 12, 31, 8);
      final texte = libelle(date);
      expect(texte, DateFormat.yMd('fr').format(date));
      expect(texte, contains('2025'));
    });

    test('date absente → libellé vide (aucun « null » affiché)', () {
      expect(libelle(null), '');
    });
  });

  group('NotificationTile — rendu', () {
    testWidgets('affiche le titre, le message et le libellé relatif',
        (tester) async {
      await _pomper(
        tester,
        _notif(creeLe: _maintenant.subtract(const Duration(minutes: 12))),
      );

      expect(find.text('Nouvelle dette'), findsOneWidget);
      expect(find.text('Awa vous a ajouté une dette'), findsOneWidget);
      expect(find.text('il y a 12 min'), findsOneWidget);
    });

    testWidgets('« À l\'instant » pour une notification qui vient d\'arriver',
        (tester) async {
      await _pomper(tester, _notif(creeLe: _maintenant));
      expect(find.text('À l\'instant'), findsOneWidget);
    });

    testWidgets('date courte au-delà de 24 h', (tester) async {
      final date = _maintenant.subtract(const Duration(days: 5));
      await _pomper(tester, _notif(creeLe: date));
      expect(find.text(DateFormat.MMMd('fr').format(date)), findsOneWidget);
    });

    testWidgets('le message n\'est pas répété quand il tient lieu de titre',
        (tester) async {
      final n = NotificationModel(
        id: '1',
        data: const {'type': 'new_debt', 'message': 'Seulement un message'},
        createdAt: _maintenant.toIso8601String(),
      );
      await _pomper(tester, n);
      expect(find.text('Seulement un message'), findsOneWidget);
    });

    testWidgets('un contenu vide retombe sur le libellé générique',
        (tester) async {
      final n = NotificationModel(
        id: '1',
        data: const {'type': 'new_debt'},
        createdAt: _maintenant.toIso8601String(),
      );
      await _pomper(tester, n);
      expect(find.text('Nouvelle notification'), findsOneWidget);
    });
  });

  group('NotificationTile — état lu / non lu lisible', () {
    testWidgets('une notification non lue affiche la pastille texte « Non lu »',
        (tester) async {
      await _pomper(tester, _notif());
      expect(find.text('Non lu'), findsOneWidget);
    });

    testWidgets('une notification lue n\'affiche pas la pastille',
        (tester) async {
      await _pomper(tester, _notif(lue: true));
      expect(find.text('Non lu'), findsNothing);
    });

    testWidgets('l\'état n\'est pas porté par la seule couleur : titre en gras',
        (tester) async {
      await _pomper(tester, _notif());
      final nonLu = tester.widget<Text>(find.text('Nouvelle dette'));
      expect(nonLu.style?.fontWeight, FontWeight.w700);

      await _pomper(tester, _notif(lue: true));
      final lu = tester.widget<Text>(find.text('Nouvelle dette'));
      expect(lu.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('l\'état est annoncé aux lecteurs d\'écran', (tester) async {
      final handle = tester.ensureSemantics();

      await _pomper(tester, _notif());
      expect(
        tester.getSemantics(find.byType(NotificationTile)).value,
        'Non lu',
      );

      await _pomper(tester, _notif(lue: true));
      expect(
        tester.getSemantics(find.byType(NotificationTile)).value,
        'Lu',
      );

      handle.dispose();
    });

    testWidgets('la tuile respecte la hauteur minimale de 72 dp',
        (tester) async {
      await _pomper(tester, _notif());
      final taille = tester.getSize(find.byType(NotificationTile));
      expect(taille.height, greaterThanOrEqualTo(72));
    });
  });

  group('NotificationTile — accessibilité à textScaler 1.5', () {
    testWidgets('aucun débordement sur une notification standard',
        (tester) async {
      await _pomper(
        tester,
        _notif(creeLe: _maintenant.subtract(const Duration(minutes: 12))),
        echelleTexte: 1.5,
      );

      expect(tester.takeException(), isNull,
          reason: 'la mise en page doit absorber un texte agrandi de 50 %');
      expect(find.text('Nouvelle dette'), findsOneWidget);
      expect(find.text('Non lu'), findsOneWidget);
      expect(find.text('il y a 12 min'), findsOneWidget);
    });

    testWidgets('aucun débordement avec une date longue sur écran étroit',
        (tester) async {
      final date = DateTime(2025, 12, 31, 8);
      await _pomper(
        tester,
        _notif(
          titre: 'Rappel d\'échéance pour une dette envers un contact',
          message: 'Le remboursement arrive à échéance demain matin, '
              'pensez à confirmer l\'opération dans l\'application.',
          creeLe: date,
        ),
        echelleTexte: 1.5,
        largeur: 300,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(DateFormat.yMd('fr').format(date)), findsOneWidget);
      expect(find.text('Non lu'), findsOneWidget,
          reason: 'la pastille passe à la ligne au lieu d\'être tronquée');
    });

    testWidgets('la tuile grandit avec le texte au lieu de le rogner',
        (tester) async {
      await _pomper(tester, _notif(), echelleTexte: 1.0);
      final hauteurNormale =
          tester.getSize(find.byType(NotificationTile)).height;

      await _pomper(tester, _notif(), echelleTexte: 1.5);
      final hauteurAgrandie =
          tester.getSize(find.byType(NotificationTile)).height;

      expect(tester.takeException(), isNull);
      expect(hauteurAgrandie, greaterThan(hauteurNormale));
    });

    testWidgets('le mode sélection reste sans débordement à 1.5',
        (tester) async {
      await _pomper(
        tester,
        _notif(),
        echelleTexte: 1.5,
        modeSelection: true,
        selectionne: true,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });
  });

  group('NotificationTile — interactions', () {
    testWidgets('l\'appui et l\'appui long sont transmis', (tester) async {
      var taps = 0;
      var longs = 0;
      await _pomper(
        tester,
        _notif(),
        onTap: () => taps++,
        onLongPress: () => longs++,
      );

      await tester.tap(find.byType(NotificationTile));
      await tester.longPress(find.byType(NotificationTile));
      expect(taps, 1);
      expect(longs, 1);
    });

    testWidgets('en mode sélection, cocher la case déclenche onTap',
        (tester) async {
      var taps = 0;
      await _pomper(
        tester,
        _notif(),
        modeSelection: true,
        onTap: () => taps++,
      );

      await tester.tap(find.byType(Checkbox));
      expect(taps, 1);
    });
  });
}
