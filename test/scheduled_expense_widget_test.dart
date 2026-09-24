import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:monitrack/providers/expense_provider.dart';
import 'package:monitrack/providers/account_provider.dart';
import 'package:monitrack/providers/profile_provider.dart';
import 'package:monitrack/providers/contact_provider.dart';
import 'package:monitrack/providers/auth_provider.dart';
import 'package:monitrack/screens/expense_screen.dart';
import 'package:monitrack/screens/add_scheduled_expense_screen.dart';

/// Providers factices : ce test vérifie uniquement le flux UI (bottom sheet →
/// formulaire), donc on neutralise tout accès réel à SQLite / réseau pour
/// rester déterministe (pas d'isolate ni de timer pendant le test).
class _NoopExpenseProvider extends ExpenseProvider {
  @override
  Future<void> loadData() async {}
}

class _NoopAccountProvider extends AccountProvider {
  @override
  Future<void> loadData() async {}
}

class _NoopContactProvider extends ContactProvider {
  @override
  Future<void> fetchContacts() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'La bottom sheet « + » propose « Dépense programmée » en 4e position '
      'et ouvre le formulaire', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ExpenseProvider>(
              create: (_) => _NoopExpenseProvider()),
          ChangeNotifierProvider<AccountProvider>(
              create: (_) => _NoopAccountProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider<ContactProvider>(
              create: (_) => _NoopContactProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExpenseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ouvre la bottom sheet comme le ferait le FAB « + ».
    final state =
        tester.state<ExpenseScreenState>(find.byType(ExpenseScreen));
    state.showAddTransactionDialog();
    await tester.pumpAndSettle();

    // 4 options, « Dépense programmée » en dernière position.
    final sheetTiles = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(ListTile),
    );
    expect(sheetTiles, findsNWidgets(4));

    final lastTileTitle = tester.widget<Text>(
      find.descendant(of: sheetTiles.last, matching: find.byType(Text)),
    );
    expect(lastTileTitle.data, 'Dépense programmée');

    // Le tap navigue vers le formulaire de dépense programmée.
    await tester.tap(sheetTiles.last);
    await tester.pumpAndSettle();
    expect(find.byType(AddScheduledExpenseScreen), findsOneWidget);
  });
}
