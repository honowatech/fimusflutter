import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/screens/expense_detail_screen.dart';
import 'package:monitrack/screens/expense_screen.dart';
import 'package:monitrack/providers/expense_provider.dart';
import 'package:monitrack/providers/account_provider.dart';
import 'package:monitrack/providers/profile_provider.dart';
import 'package:monitrack/providers/auth_provider.dart';
import 'package:monitrack/providers/contact_provider.dart';
import 'package:monitrack/models/expense.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Expense makeExpense({
    DateTime? date,
    DateTime? createdAt,
    String? creatorName,
    String? creatorId,
  }) {
    return Expense(
      id: 'exp_detail_1',
      title: 'Courses marché',
      amount: 25000.0,
      category: 'Alimentation',
      date: date ?? DateTime.now(),
      type: 'expense',
      creatorId: creatorId ?? 'user_1',
      creatorName: creatorName,
      createdAt: createdAt,
    );
  }

  Widget wrapApp(
    Widget home,
    ExpenseProvider expenseProvider,
    AccountProvider accountProvider,
  ) {
    final profileProvider = ProfileProvider();
    final authProvider = AuthProvider();
    final contactProvider = ContactProvider();
    return MultiProvider(
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
        home: home,
      ),
    );
  }

  testWidgets('L\'écran de détail affiche date d\'enregistrement, date d\'opération et créateur',
      (WidgetTester tester) async {
    late ExpenseProvider expenseProvider;
    late AccountProvider accountProvider;
    await tester.runAsync(() async {
      expenseProvider = ExpenseProvider();
      accountProvider = AccountProvider();
      await expenseProvider.loadData();
      await accountProvider.loadData();
    });

    final expenseDate = DateTime(2026, 8, 10, 9, 30);
    final recordedDate = DateTime(2026, 8, 12, 14, 5);

    await tester.pumpWidget(wrapApp(
      ExpenseDetailScreen(
        expense: makeExpense(date: expenseDate, createdAt: recordedDate, creatorName: 'Alice'),
      ),
      expenseProvider,
      accountProvider,
    ));
    await tester.pumpAndSettle();

    // En-tête : titre et montant.
    expect(find.text('Courses marché'), findsOneWidget);
    expect(find.text('-25 000.00 CFA'), findsOneWidget);

    // Informations détaillées.
    expect(find.text('Détails de l\'opération'), findsOneWidget);
    expect(find.text('Date de l\'opération'), findsOneWidget);
    expect(find.text('10/08/2026 à 09:30'), findsOneWidget);
    expect(find.text('Date d\'enregistrement'), findsOneWidget);
    expect(find.text('12/08/2026 à 14:05'), findsOneWidget);
    expect(find.text('Enregistrée par'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Aucun compte'), findsOneWidget);
  });

  testWidgets('Un clic sur une dépense de l\'historique ouvre le détail',
      (WidgetTester tester) async {
    late ExpenseProvider expenseProvider;
    late AccountProvider accountProvider;
    await tester.runAsync(() async {
      expenseProvider = ExpenseProvider();
      accountProvider = AccountProvider();
      await expenseProvider.loadData();
      await accountProvider.loadData();

      final now = DateTime.now();
      await expenseProvider.addExpense(makeExpense(
        date: now.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 2)),
        creatorName: 'Alice',
      ));
    });

    await tester.pumpWidget(wrapApp(ExpenseScreen(), expenseProvider, accountProvider));
    // Laisse l'async se terminer.
    await tester.pump(const Duration(seconds: 1));

    // Onglet Historique.
    await tester.tap(find.descendant(
      of: find.byType(TabBar),
      matching: find.text('Historique'),
    ));
    await tester.pumpAndSettle();

    // La dépense apparaît dans l'historique.
    expect(find.text('Courses marché'), findsOneWidget);

    // Clic sur la dépense → écran de détail.
    await tester.tap(find.text('Courses marché'));
    await tester.pumpAndSettle();

    expect(find.text('Détails de l\'opération'), findsOneWidget);
    expect(find.text('Date d\'enregistrement'), findsOneWidget);
    expect(find.text('Enregistrée par'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });
}
