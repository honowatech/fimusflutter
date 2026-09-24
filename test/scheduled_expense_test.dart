import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:monitrack/models/expense.dart';
import 'package:monitrack/providers/expense_provider.dart';
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

  group('Modèle — dépense programmée', () {
    test('round-trip DB : scheduleStatus et reminderAt sont préservés', () {
      final reminder = DateTime.now().add(const Duration(days: 3));
      final scheduled = Expense(
        id: 'sched-1',
        title: 'Abonnement Internet',
        amount: 25000,
        category: 'Factures',
        date: reminder,
        type: 'expense',
        isPlanned: true,
        isLinkedToCashFlow: false,
        scheduleStatus: 'scheduled',
        reminderAt: reminder,
      );

      final dbRow = scheduled.toDbMap();
      expect(dbRow['scheduleStatus'], 'scheduled');
      expect(dbRow['reminderAt'], reminder.toIso8601String());

      final fromDb = Expense.fromDbMap(dbRow);
      expect(fromDb.scheduleStatus, 'scheduled');
      expect(fromDb.reminderAt, reminder);
      expect(fromDb.isPlanned, isTrue);
      expect(fromDb.isLinkedToCashFlow, isFalse);
    });

    test('round-trip JSON : clés camelCase et snake_case acceptées', () {
      final reminder = DateTime.now().add(const Duration(days: 3));
      final scheduled = Expense(
        id: 'sched-2',
        title: 'Loyer',
        amount: 150000,
        category: 'Logement',
        date: reminder,
        type: 'expense',
        scheduleStatus: 'scheduled',
        reminderAt: reminder,
      );

      final fromJson = Expense.fromJson(scheduled.toJson());
      expect(fromJson.scheduleStatus, 'scheduled');
      expect(fromJson.reminderAt, reminder);

      final fromSnake = Expense.fromJson({
        'id': 'sched-3',
        'title': 'Facture eau',
        'amount': 8000,
        'category': 'Factures',
        'date': DateTime.now().toIso8601String(),
        'type': 'expense',
        'schedule_status': 'scheduled',
        'reminder_at': reminder.toIso8601String(),
      });
      expect(fromSnake.scheduleStatus, 'scheduled');
      expect(fromSnake.reminderAt, reminder);
    });

    test('sync serveur : reminder_at sans offset est parsé en heure locale (heure murale)', () {
      // Le backend renvoie l'heure murale choisie par l'utilisateur, sans
      // offset UTC. Elle doit être comprise telle quelle par l'appareil,
      // pour que tz.TZDateTime.from planifie le rappel à la même heure.
      const serverWallClock = '2026-08-20T09:30:00';

      final fromServer = Expense.fromJson({
        'id': 'sched-server-1',
        'title': 'Abonnement',
        'amount': 10000,
        'category': 'Factures',
        'date': serverWallClock,
        'type': 'expense',
        'schedule_status': 'scheduled',
        'reminder_at': serverWallClock,
      });
      expect(fromServer.reminderAt, isNotNull);
      expect(fromServer.reminderAt!.isUtc, isFalse,
          reason: 'sans offset, la date doit rester locale');
      expect(fromServer.reminderAt!.hour, 9);
      expect(fromServer.reminderAt!.minute, 30);
      expect(fromServer.date.isUtc, isFalse);
    });

    test('confirmAsRealExpense bascule les flags et conserve id/date/compte', () {
      final reminder = DateTime.now().add(const Duration(days: 2));
      final scheduled = Expense(
        id: 'sched-9',
        title: 'Loyer',
        amount: 150000,
        category: 'Logement',
        date: reminder,
        type: 'expense',
        accountId: 'acc-1',
        isPlanned: true,
        isLinkedToCashFlow: false,
        scheduleStatus: 'scheduled',
        reminderAt: reminder,
      );

      final confirmed = scheduled.confirmAsRealExpense();
      expect(confirmed.id, 'sched-9');
      expect(confirmed.isPlanned, isFalse);
      expect(confirmed.isLinkedToCashFlow, isTrue);
      expect(confirmed.scheduleStatus, isNull);
      expect(confirmed.reminderAt, isNull);
      expect(confirmed.accountId, 'acc-1');
      expect(confirmed.amount, 150000);
      expect(confirmed.date, reminder);
      expect(confirmed.updatedAt, isNotNull);
    });
  });

  group('Provider — cycle de vie d\'une dépense programmée', () {
    Future<ExpenseProvider> newProvider() async {
      final provider = ExpenseProvider();
      await provider.loadData();
      return provider;
    }

    Expense scheduledExpense(String id, DateTime reminderAt, {String? accountId}) {
      return Expense(
        id: id,
        title: 'Dépense programmée $id',
        amount: 45000,
        category: 'Autre',
        date: reminderAt,
        type: 'expense',
        accountId: accountId,
        isPlanned: true,
        isLinkedToCashFlow: false,
        scheduleStatus: 'scheduled',
        reminderAt: reminderAt,
      );
    }

    test('création → dans scheduledExpenses, absente des statistiques', () async {
      final provider = await newProvider();
      final reminder = DateTime.now().add(const Duration(days: 4));

      await provider.addExpense(scheduledExpense('sched-flow-1', reminder));
      await provider.loadData();

      expect(provider.scheduledExpenses.map((e) => e.id), contains('sched-flow-1'));
      expect(provider.scheduledExpenses.single.reminderAt, reminder);

      // La dépense programmée ne doit pas polluer les stats cash-flow.
      final start = DateTime.now().subtract(const Duration(days: 1));
      final end = DateTime.now().add(const Duration(days: 30));
      final idsInStats =
          provider.getFilteredExpenses(start, end).map((e) => e.id);
      expect(idsInStats, isNot(contains('sched-flow-1')));
      expect(provider.getTotalExpenses(start, end), 0);
    });

    test('confirmation → bascule en dépense réelle et débite le compte', () async {
      final db = await DatabaseService.instance.database;
      await db.insert('accounts', {
        'id': 'acc-flow-1',
        'name': 'Compte Principal',
        'balance': 500000.0,
        'is_synced': 1,
        'sync_action': 'updated',
      });

      final provider = await newProvider();
      final reminder = DateTime.now().add(const Duration(days: 2));
      await provider.addExpense(
        scheduledExpense('sched-flow-2', reminder, accountId: 'acc-flow-1'),
      );
      await provider.loadData();

      final ok = await provider.confirmScheduledExpense('sched-flow-2');
      expect(ok, isTrue);

      final row =
          provider.expenses.firstWhere((e) => e.id == 'sched-flow-2');
      expect(row.isPlanned, isFalse);
      expect(row.isLinkedToCashFlow, isTrue);
      expect(row.scheduleStatus, isNull);

      // Désormais visible dans les statistiques.
      final start = DateTime.now().subtract(const Duration(days: 1));
      final end = DateTime.now().add(const Duration(days: 30));
      final idsInStats =
          provider.getFilteredExpenses(start, end).map((e) => e.id);
      expect(idsInStats, contains('sched-flow-2'));

      // Solde du compte débité en base (500 000 - 45 000).
      final accounts =
          await db.query('accounts', where: 'id = ?', whereArgs: ['acc-flow-1']);
      expect(accounts.single['balance'], 455000.0);
    });

    test('confirmation → la dépense est datée du jour (visible dans l\'historique)', () async {
      final provider = await newProvider();
      final reminder = DateTime.now().add(const Duration(days: 2));
      await provider.addExpense(scheduledExpense('sched-flow-6', reminder));
      await provider.loadData();

      final ok = await provider.confirmScheduledExpense('sched-flow-6');
      expect(ok, isTrue);

      final row = provider.expenses.firstWhere((e) => e.id == 'sched-flow-6');
      // La date d'enregistrement est la date de confirmation, pas l'échéance
      // future : sans cela la dépense confirmée n'apparaîtrait pas dans
      // l'historique (filtre jusqu'à aujourd'hui).
      expect(row.date.isAfter(DateTime.now().subtract(const Duration(hours: 1))), isTrue);
      expect(row.date.isBefore(DateTime.now().add(const Duration(hours: 1))), isTrue);

      // Visible dans une fenêtre « maintenant », ce que montre l'historique.
      final start = DateTime.now().subtract(const Duration(hours: 1));
      final end = DateTime.now().add(const Duration(hours: 1));
      final idsInStats =
          provider.getFilteredExpenses(start, end).map((e) => e.id);
      expect(idsInStats, contains('sched-flow-6'));
    });

    test('annulation → suppression douce, absente des listes', () async {
      final provider = await newProvider();
      final reminder = DateTime.now().add(const Duration(days: 3));
      await provider.addExpense(scheduledExpense('sched-flow-3', reminder));
      await provider.loadData();
      expect(provider.scheduledExpenses, hasLength(1));

      final ok = await provider.cancelScheduledExpense('sched-flow-3');
      expect(ok, isTrue);

      final db = await DatabaseService.instance.database;
      final rows = await db.query('expenses',
          where: 'id = ?', whereArgs: ['sched-flow-3']);
      expect(rows.single['sync_action'], 'delete'); // tombstone conservé pour la sync

      await provider.loadData();
      expect(provider.scheduledExpenses.map((e) => e.id),
          isNot(contains('sched-flow-3')));
    });

    test('upcomingScheduledExpensesCount ne compte que les échéances futures', () async {
      final provider = await newProvider();
      final now = DateTime.now();

      await provider.addExpense(
        scheduledExpense('sched-flow-4', now.add(const Duration(days: 3))),
      );
      await provider.addExpense(
        scheduledExpense('sched-flow-5', now.subtract(const Duration(days: 1))),
      );
      await provider.loadData();

      expect(provider.scheduledExpenses, hasLength(2));
      expect(provider.upcomingScheduledExpensesCount, 1);
    });
  });
}
