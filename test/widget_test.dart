
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/screens/expense_screen.dart';
import 'package:monitrack/providers/expense_provider.dart';
import 'package:monitrack/providers/account_provider.dart';
import 'package:monitrack/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';

void main() {
  testWidgets('ExpenseScreen test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
          ChangeNotifierProvider(create: (_) => AccountProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: ExpenseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}
