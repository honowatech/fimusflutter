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
import 'package:monitrack/screens/add_debt_operation_screen.dart';
import 'package:monitrack/models/contact.dart';

/// Providers factices : neutralise SQLite / réseau pour rester déterministe.
///
/// [addToContactsOnAdd] à false + [applyUpsert] à false simulent une liste
/// obsolète au moment du rebuild (fetchContacts concurrent qui écrase la
/// liste après la création du contact, et écran qui ne la met pas à jour).
class _FakeContactProvider extends ContactProvider {
  _FakeContactProvider({this.addToContactsOnAdd = true, this.applyUpsert = true});

  final bool addToContactsOnAdd;
  final bool applyUpsert;
  final List<Contact> _fakeContacts = [];

  @override
  List<Contact> get contacts => _fakeContacts;

  @override
  Future<void> fetchContacts() async {}

  @override
  Future<Contact> addContact(String code, {String? alias}) async {
    final contact = Contact(
      id: 42,
      name: 'Jean Dupont',
      email: 'jean@example.com',
      userCode: code,
      alias: alias,
    );
    if (addToContactsOnAdd) {
      upsertContact(contact);
    }
    return contact;
  }

  @override
  void upsertContact(Contact contact) {
    if (!applyUpsert) return;
    _fakeContacts.removeWhere((c) => c.id == contact.id);
    _fakeContacts.add(contact);
    notifyListeners();
  }
}

class _FakeExpenseProvider extends ExpenseProvider {
  @override
  Future<void> loadData() async {}
}

class _FakeAccountProvider extends AccountProvider {
  @override
  Future<void> loadData() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpDebtScreen(WidgetTester tester,
      {bool contactInListOnAdd = true, bool applyUpsert = true}) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ExpenseProvider>(
              create: (_) => _FakeExpenseProvider()),
          ChangeNotifierProvider<AccountProvider>(
              create: (_) => _FakeAccountProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider<ContactProvider>(
              create: (_) => _FakeContactProvider(
                  addToContactsOnAdd: contactInListOnAdd,
                  applyUpsert: applyUpsert)),
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
          home: const AddDebtOperationScreen(initialIsIncome: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Ouvre la bottom sheet « Ajouter un contact » depuis le dropdown.
  Future<void> openAndSubmitContactSheet(WidgetTester tester,
      {String pseudo = 'jean_dupont'}) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nouveau contact'));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter un contact'), findsOneWidget);

    final sheet = find.byType(BottomSheet);
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextFormField)).first,
      pseudo,
    );
    await tester.tap(
      find.descendant(
          of: sheet, matching: find.widgetWithText(ElevatedButton, 'Ajouter')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Créer un contact depuis l\'écran d\'emprunt sélectionne le contact '
      'et laisse le formulaire valide', (tester) async {
    await pumpDebtScreen(tester);

    await openAndSubmitContactSheet(tester);

    // Le contact créé doit être affiché dans le champ (RichText « 👤 Jean Dupont »).
    expect(find.textContaining('Jean Dupont', findRichText: true), findsOneWidget);

    // L'état interne du champ doit être à jour et sans erreur de validation :
    // c'est lui qui est utilisé par Form.validate() au moment de l'enregistrement.
    final dropdownState = tester.state<FormFieldState<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdownState.value, 'contact_42');
    expect(dropdownState.errorText, isNull);
  });

  testWidgets(
      'Créer un contact alors que la liste est obsolète (fetch concurrent) '
      'ne plante pas le dropdown', (tester) async {
    await pumpDebtScreen(tester,
        contactInListOnAdd: false, applyUpsert: false);

    await openAndSubmitContactSheet(tester);

    // Aucune assertion DropdownButtonFormField (« exactly one item ») ne doit
    // être levée, même si le contact créé n'apparaît pas dans la liste.
    expect(tester.takeException(), isNull);

    // L'écran reste utilisable : le champ est toujours présent.
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });
}
