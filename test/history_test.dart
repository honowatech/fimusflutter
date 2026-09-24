import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/screens/expense_screen.dart';
import 'package:monitrack/providers/expense_provider.dart';
import 'package:monitrack/providers/account_provider.dart';
import 'package:monitrack/providers/profile_provider.dart';
import 'package:monitrack/models/expense.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitrack/providers/auth_provider.dart';
import 'package:monitrack/providers/contact_provider.dart';
import 'package:monitrack/services/database_service.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Base en mémoire : chaque suite de tests est isolée (les suites tournant
    // en parallèle sur un fichier partagé provoquent des « database is locked »).
    await DatabaseService.instance.switchDatabase(
        name: inMemoryDatabasePath);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseService.instance.clearDevDatabase();
  });

  testWidgets('Expense Screen History Tab test with reload', (WidgetTester tester) async {
    // SQLite (isolate ffi) est du vrai asynchrone : les providers doivent être
    // créés et chargés dans runAsync. S'ils sont créés dans le corps du test
    // (zone FakeAsync), leur loadData ne se termine jamais.
    late ExpenseProvider expenseProvider1;
    late AccountProvider accountProvider;
    await tester.runAsync(() async {
      expenseProvider1 = ExpenseProvider();
      accountProvider = AccountProvider();
      await expenseProvider1.loadData();
      await accountProvider.loadData();

      // Add an expense today
      final now = DateTime.now();
      await expenseProvider1.addExpense(Expense(
        id: 'test_expense_1',
        title: 'Coffee',
        amount: 1500.0,
        category: 'Alimentation',
        date: now,
        type: 'expense',
      ));

      // Instantiate a new provider to force loading from SharedPreferences
      final expenseProvider2 = ExpenseProvider();
      await expenseProvider2.loadData();
    });

    final profileProvider = ProfileProvider();
    final authProvider = AuthProvider();
    final contactProvider = ContactProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: expenseProvider1),
          ChangeNotifierProvider.value(value: accountProvider),
          ChangeNotifierProvider.value(value: profileProvider),
          ChangeNotifierProvider.value(value: contactProvider),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: ExpenseScreen(),
        ),
      ),
    );

    // Let the async loading complete
    await tester.pump(const Duration(seconds: 1));

    // Tap on the History tab (second tab) — cible l'onglet, pas le titre
    // de section « Historique » du dashboard.
    await tester.tap(find.descendant(
      of: find.byType(TabBar),
      matching: find.text('Historique'),
    ));
    await tester.pumpAndSettle();

    // Verify if "Coffee" is displayed
    expect(find.text('Coffee'), findsOneWidget);
  });

  testWidgets('History tab displays scheduled expenses with "Programmées" filter', (WidgetTester tester) async {
    late ExpenseProvider expenseProvider;
    late AccountProvider accountProvider;
    await tester.runAsync(() async {
      expenseProvider = ExpenseProvider();
      accountProvider = AccountProvider();
      await expenseProvider.loadData();
      await accountProvider.loadData();

      // Dépense réelle (vue « Dépenses » par défaut de l'onglet Historique).
      await expenseProvider.addExpense(Expense(
        id: 'test_expense_real',
        title: 'Coffee',
        amount: 1500.0,
        category: 'Alimentation',
        date: DateTime.now(),
        type: 'expense',
      ));

      // Dépense programmée à venir.
      final reminder = DateTime.now().add(const Duration(days: 5));
      await expenseProvider.addExpense(Expense(
        id: 'test_expense_scheduled',
        title: 'Loyer programmé',
        amount: 50000.0,
        category: 'Logement',
        date: reminder,
        type: 'expense',
        isLinkedToCashFlow: false,
        isPlanned: true,
        scheduleStatus: 'scheduled',
        reminderAt: reminder,
      ));
    });

    final profileProvider = ProfileProvider();
    final authProvider = AuthProvider();
    final contactProvider = ContactProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: expenseProvider),
          ChangeNotifierProvider.value(value: accountProvider),
          ChangeNotifierProvider.value(value: profileProvider),
          ChangeNotifierProvider.value(value: contactProvider),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: ExpenseScreen(),
        ),
      ),
    );

    // Let the async loading complete
    await tester.pump(const Duration(seconds: 1));

    // Tap on the History tab
    await tester.tap(find.descendant(
      of: find.byType(TabBar),
      matching: find.text('Historique'),
    ));
    await tester.pumpAndSettle();

    // La dépense programmée n'apparaît pas dans la vue « Dépenses » par défaut.
    expect(find.text('Loyer programmé'), findsNothing);

    // Choisir « Programmées » dans le filtre de type (dernier DropdownButton).
    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programmées').last);
    await tester.pumpAndSettle();

    // La dépense programmée est maintenant affichée dans l'historique.
    expect(find.text('Loyer programmé'), findsOneWidget);
    // La dépense réelle n'y figure plus.
    expect(find.text('Coffee'), findsNothing);
  });
}
