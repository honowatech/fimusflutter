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

void main() {
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: expenseProvider2),
          ChangeNotifierProvider.value(value: accountProvider),
          ChangeNotifierProvider.value(value: profileProvider),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: ExpenseScreen(),
        ),
      ),
    );

    // Let the async loading complete by pumping the widget tree
    await tester.pumpAndSettle();

    // Tap on the History tab (second tab)
    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();

    // Verify if "Coffee" is displayed
    expect(find.text('Coffee'), findsOneWidget);
  });
}
