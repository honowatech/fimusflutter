import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/providers/expense_provider.dart';
import 'package:monitrack/services/database_service.dart';
import 'package:monitrack/utils/category_normalizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Base en mémoire, isolée des autres suites (fichier partagé → locked).
    await DatabaseService.instance.switchDatabase(
        name: inMemoryDatabasePath);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseService.instance.clearDevDatabase();
  });

  group('normalizeCategory', () {
    test('met chaque mot en Title case, plusieurs mots autorisés', () {
      expect(normalizeCategory('VENTE de BIEN'), 'Vente De Bien');
      expect(normalizeCategory('pension retraite'), 'Pension Retraite');
      expect(
          normalizeCategory('REMBOURSEMENT prêt VOYAGE'),
          'Remboursement Prêt Voyage');
      expect(normalizeCategory('alImEnTaTion'), 'Alimentation');
    });

    test('réduit les espaces superflus', () {
      expect(normalizeCategory('  Vente   de    BIEN  '), 'Vente De Bien');
      expect(normalizeCategory('  alImEnTaTion '), 'Alimentation');
    });

    test('préserve les accents', () {
      expect(normalizeCategory('BÉNÉFICES'), 'Bénéfices');
      expect(normalizeCategory('HÉRITAGES'), 'Héritages');
      expect(normalizeCategory('REÇU FACTURE'), 'Reçu Facture');
    });

    test('gère la chaîne vide', () {
      expect(normalizeCategory(''), '');
      expect(normalizeCategory('   '), '');
    });
  });

  group('categorySortKey', () {
    test('est insensible à la casse et aux accents', () {
      expect(categorySortKey('Bénéfices'), categorySortKey('benefices'));
      expect(categorySortKey('École'), 'ecole');
      expect(categorySortKey('École').compareTo(categorySortKey('Factures')) < 0,
          isTrue);
    });

    test('produit un ordre alphabétique français correct', () {
      final words = ['École', 'Factures', 'Autre', 'Dons', 'Bénéfices'];
      words.sort((a, b) => categorySortKey(a).compareTo(categorySortKey(b)));
      expect(words, ['Autre', 'Bénéfices', 'Dons', 'École', 'Factures']);
    });
  });

  group('persistance SQLite des catégories (ExpenseProvider)', () {
    testWidgets('addCategory normalise, déduplique et persiste',
        (tester) async {
      await tester.runAsync(() async {
        final provider = ExpenseProvider();
        await provider.loadData();

        // Saisie libre multi-mots : normalisée à la création
        await provider.addCategory('  sAlAiReS  mensuel ', isIncome: true);
        expect(provider.incomeCategories, contains('Salaires Mensuel'));

        // Doublon par nom normalisé : rien n'est réinséré
        await provider.addCategory('Salaires  Mensuel', isIncome: true);
        expect(
          provider.incomeCategories.where((c) => c == 'Salaires Mensuel').length,
          1,
        );

        // Côté dépenses également
        await provider.addCategory('vente de bien', isIncome: false);
        expect(provider.expenseCategories, contains('Vente De Bien'));

        // Rechargement depuis SQLite : les catégories créées sont persistées
        final reloaded = ExpenseProvider();
        await reloaded.loadData();
        expect(reloaded.incomeCategories, contains('Salaires Mensuel'));
        expect(reloaded.expenseCategories, contains('Vente De Bien'));
      });
    });

    testWidgets('les listes de catégories sont triées alphabétiquement',
        (tester) async {
      await tester.runAsync(() async {
        final provider = ExpenseProvider();
        await provider.loadData();

        await provider.addCategory('Zoo');
        await provider.addCategory('Antenne');
        await provider.addCategory('École');

        final keys = provider.expenseCategories.map(categorySortKey).toList();
        expect(keys, orderedEquals([...keys]..sort()));
      });
    });

    testWidgets('deleteCategory est local : tombstones au rechargement',
        (tester) async {
      await tester.runAsync(() async {
        final provider = ExpenseProvider();
        await provider.loadData();
        expect(provider.incomeCategories, contains('Salaires'));

        await provider.deleteCategory('Salaires', isIncome: true);
        expect(provider.incomeCategories, isNot(contains('Salaires')));

        // Rechargement : le tombstones empêche le retour de « Salaires »
        final reloaded = ExpenseProvider();
        await reloaded.loadData();
        expect(reloaded.incomeCategories, isNot(contains('Salaires')));

        // « Autre » est protégée contre la suppression
        await provider.deleteCategory('Autre', isIncome: true);
        expect(provider.incomeCategories, contains('Autre'));
      });
    });
  });
}
