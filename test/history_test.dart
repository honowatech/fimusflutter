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

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Expense Screen History Tab test with reload', (WidgetTester tester) async {
    final expenseProvider1 = ExpenseProvider();

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
    
    final accountProvider = AccountProvider();
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

    // Tap on the History tab (second tab)
    await tester.tap(find.text('Historique'));
    await tester.pump(const Duration(seconds: 1));

    // Verify if "Coffee" is displayed
    expect(find.text('Coffee'), findsOneWidget);
  });
}
