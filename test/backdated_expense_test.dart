import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:monitrack/models/expense.dart';
import 'package:monitrack/providers/expense_provider.dart';
import 'package:monitrack/providers/account_provider.dart';
import 'package:monitrack/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    // Base en mémoire : chaque suite de tests est isolée (les suites tournant
    // en parallèle sur un fichier partagé provoquent des « database is locked »).
    await DatabaseService.instance.switchDatabase(
        name: inMemoryDatabasePath);
    await DatabaseService.instance.clearDevDatabase();
  });

  Expense backdatedExpense(String id, DateTime date, {String? accountId}) {
    return Expense(
      id: id,
      title: 'Dépense antidatée $id',
      amount: 10000.0,
      category: 'Autre',
      date: date,
      type: 'expense',
      accountId: accountId,
    );
  }

  group('Dépenses antidatées — enregistrement', () {
    test('round-trip DB : la date antidatée est préservée à l\'identique', () async {
      final db = await DatabaseService.instance.database;
      final backdated = DateTime(2025, 3, 15, 9, 30);

      final exp = backdatedExpense('bd-roundtrip-1', backdated);
      await db.insert('expenses', exp.toDbMap());

      final rows = await db.query('expenses',
          where: 'id = ?', whereArgs: ['bd-roundtrip-1']);
      expect(rows, hasLength(1));
      // La date stockée est le timestamp ISO exact de la date antidatée.
      expect(rows.single['date'], backdated.toIso8601String());

      final fromDb = Expense.fromDbMap(rows.single);
      expect(fromDb.date, backdated);
    });

    test('addExpense : présente dans la liste, correctement triée et filtrable', () async {
      final provider = ExpenseProvider();
      await provider.loadData();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12, 0);
      final backdated = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 45));

      await provider.addExpense(backdatedExpense('bd-add-1', backdated));
      await provider.addExpense(backdatedExpense('bd-add-2', today));

      // Les deux dépenses sont enregistrées et la plus récente passe en tête.
      expect(provider.expenses.map((e) => e.id),
          containsAll(['bd-add-1', 'bd-add-2']));
      expect(provider.expenses.first.id, 'bd-add-2');

      // Visible dans une période qui couvre sa date, invisible sur 7 jours.
      final wideStart = backdated.subtract(const Duration(days: 1));
      final wideEnd = backdated.add(const Duration(days: 1));
      final idsWide =
          provider.getFilteredExpenses(wideStart, wideEnd).map((e) => e.id);
      expect(idsWide, contains('bd-add-1'));

      final weekStart = now.subtract(const Duration(days: 7));
      // Fenêtre jusqu'à la fin de la journée : la dépense « du jour » datée
      // de 12h00 reste visible quel que soit l'heure d'exécution du test.
      final weekEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      final idsWeek =
          provider.getFilteredExpenses(weekStart, weekEnd).map((e) => e.id);
      expect(idsWeek, isNot(contains('bd-add-1')));
      expect(idsWeek, contains('bd-add-2'));

      // Le total d'une période donnée inclut bien la dépense antidatée.
      final totalWide = provider.getTotalExpenses(wideStart, wideEnd);
      expect(totalWide, 10000.0);
    });

    test('le compte lié est débité du montant, quelle que soit la date', () async {
      final db = await DatabaseService.instance.database;
      await db.insert('accounts', {
        'id': 'bd-acc-1',
        'name': 'Compte Principal',
        'balance': 500000.0,
        'is_synced': 1,
        'sync_action': 'updated',
      });

      final provider = ExpenseProvider();
      await provider.loadData();
      final accountProvider = AccountProvider();
      await accountProvider.loadData();

      final backdated = DateTime.now().subtract(const Duration(days: 30));

      // Reproduit le flux réel d'AddExpenseScreen : insertion de la dépense
      // et débit du compte dans la même transaction.
      await DatabaseService.instance.runTransaction((txn) async {
        await provider.addExpense(backdatedExpense('bd-balance-1', backdated,
            accountId: 'bd-acc-1'), executor: txn);
        await accountProvider.updateBalance('bd-acc-1', -10000.0, executor: txn);
      });

      final accounts =
          await db.query('accounts', where: 'id = ?', whereArgs: ['bd-acc-1']);
      expect(accounts.single['balance'], 490000.0);
    });

    test('modification : la date antidatée est conservée si non modifiée', () async {
      final provider = ExpenseProvider();
      await provider.loadData();

      final backdated = DateTime.now().subtract(const Duration(days: 20));
      await provider.addExpense(backdatedExpense('bd-edit-1', backdated));

      final original = provider.expenses.firstWhere((e) => e.id == 'bd-edit-1');
      await provider.updateExpense(original.copyWith(title: 'Titre modifié'));

      final row = provider.expenses.firstWhere((e) => e.id == 'bd-edit-1');
      expect(row.title, 'Titre modifié');
      expect(row.date, backdated);

      // Rechargement depuis la base : la date est toujours la bonne.
      await provider.loadData();
      final reloaded =
          provider.expenses.firstWhere((e) => e.id == 'bd-edit-1');
      expect(reloaded.date, backdated);
    });

    test('persistance : visible après rechargement complet du provider', () async {
      final provider = ExpenseProvider();
      await provider.loadData();

      final backdated = DateTime.now().subtract(const Duration(days: 90));
      await provider.addExpense(backdatedExpense('bd-persist-1', backdated));

      // Nouveau provider = relecture depuis SQLite (simule un redémarrage).
      final provider2 = ExpenseProvider();
      await provider2.loadData();

      final reloaded =
          provider2.expenses.firstWhere((e) => e.id == 'bd-persist-1');
      expect(reloaded.date, backdated);
      expect(reloaded.amount, 10000.0);
      expect(reloaded.type, 'expense');
    });
  });
}
