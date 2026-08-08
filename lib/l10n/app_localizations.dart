import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'FIMUS'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @preferences.
  ///
  /// In fr, this message translates to:
  /// **'Préférences'**
  String get preferences;

  /// No description provided for @operators.
  ///
  /// In fr, this message translates to:
  /// **'Opérateurs'**
  String get operators;

  /// No description provided for @ussdCodes.
  ///
  /// In fr, this message translates to:
  /// **'Codes USSD'**
  String get ussdCodes;

  /// No description provided for @ussdCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories USSD'**
  String get ussdCategories;

  /// No description provided for @expenseCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories Dépenses'**
  String get expenseCategories;

  /// No description provided for @appLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'application'**
  String get appLanguage;

  /// No description provided for @currency.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get currency;

  /// No description provided for @french.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get french;

  /// No description provided for @english.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @addOperator.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un opérateur'**
  String get addOperator;

  /// No description provided for @addUssdCodeFor.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un code USSD pour :'**
  String get addUssdCodeFor;

  /// No description provided for @noOperatorAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucun opérateur disponible. Ajoutez-en un d\'abord.'**
  String get noOperatorAvailable;

  /// No description provided for @addExpenseCategory.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une catégorie de dépense'**
  String get addExpenseCategory;

  /// No description provided for @addUssdCategory.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une catégorie USSD'**
  String get addUssdCategory;

  /// No description provided for @categoryName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la catégorie'**
  String get categoryName;

  /// No description provided for @addNew.
  ///
  /// In fr, this message translates to:
  /// **'Créer Nouvelle'**
  String get addNew;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @editOperator.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'opérateur'**
  String get editOperator;

  /// No description provided for @country.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get country;

  /// No description provided for @allCountries.
  ///
  /// In fr, this message translates to:
  /// **'Tous les pays'**
  String get allCountries;

  /// No description provided for @sortByCountry.
  ///
  /// In fr, this message translates to:
  /// **'Trier par pays'**
  String get sortByCountry;

  /// No description provided for @operatorName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'opérateur'**
  String get operatorName;

  /// No description provided for @yourPhoneNumber.
  ///
  /// In fr, this message translates to:
  /// **'Votre numéro de téléphone'**
  String get yourPhoneNumber;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @deleteOperator.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'opérateur'**
  String get deleteOperator;

  /// No description provided for @deleteOperatorConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer l\'opérateur {name} ? Toutes les opérations USSD associées seront également supprimées.'**
  String deleteOperatorConfirm(String name);

  /// No description provided for @deleteOperation.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'opération'**
  String get deleteOperation;

  /// No description provided for @deleteOperationConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer l\'opération {name} ?'**
  String deleteOperationConfirm(String name);

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @myNumber.
  ///
  /// In fr, this message translates to:
  /// **'Mon numéro: {number}'**
  String myNumber(String number);

  /// No description provided for @noNumberDefined.
  ///
  /// In fr, this message translates to:
  /// **'Aucun numéro défini'**
  String get noNumberDefined;

  /// No description provided for @availableVariables.
  ///
  /// In fr, this message translates to:
  /// **'Variables disponibles: {variables}'**
  String availableVariables(String variables);

  /// No description provided for @ussdTemplate.
  ///
  /// In fr, this message translates to:
  /// **'Modèle de code USSD'**
  String get ussdTemplate;

  /// No description provided for @codeUpdatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Code mis à jour avec succès'**
  String get codeUpdatedSuccess;

  /// No description provided for @resetToDefault.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get resetToDefault;

  /// No description provided for @codeResetSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Code réinitialisé par défaut'**
  String get codeResetSuccess;

  /// No description provided for @cannotDeleteOther.
  ///
  /// In fr, this message translates to:
  /// **'La catégorie \'Autre\' ne peut pas être supprimée'**
  String get cannotDeleteOther;

  /// No description provided for @expenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get expenses;

  /// No description provided for @dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get dashboard;

  /// No description provided for @history.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get history;

  /// No description provided for @accounts.
  ///
  /// In fr, this message translates to:
  /// **'Comptes'**
  String get accounts;

  /// No description provided for @newOperation.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle opération'**
  String get newOperation;

  /// No description provided for @ussdMenu.
  ///
  /// In fr, this message translates to:
  /// **'USSD'**
  String get ussdMenu;

  /// No description provided for @expense.
  ///
  /// In fr, this message translates to:
  /// **'Dépense'**
  String get expense;

  /// No description provided for @income.
  ///
  /// In fr, this message translates to:
  /// **'Revenu'**
  String get income;

  /// No description provided for @monthOverview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu du mois'**
  String get monthOverview;

  /// No description provided for @incomes.
  ///
  /// In fr, this message translates to:
  /// **'Revenus'**
  String get incomes;

  /// No description provided for @yourAccounts.
  ///
  /// In fr, this message translates to:
  /// **'Vos Comptes'**
  String get yourAccounts;

  /// No description provided for @totalBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde Total'**
  String get totalBalance;

  /// No description provided for @noAccountSaved.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte enregistré.'**
  String get noAccountSaved;

  /// No description provided for @today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois'**
  String get thisMonth;

  /// No description provided for @all.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get all;

  /// No description provided for @noOperationPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération pour cette période.'**
  String get noOperationPeriod;

  /// No description provided for @addAccount.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un compte'**
  String get addAccount;

  /// No description provided for @editAccount.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le compte'**
  String get editAccount;

  /// No description provided for @accountName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du compte (ex: Espèces, Banque)'**
  String get accountName;

  /// No description provided for @initialBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde initial'**
  String get initialBalance;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce compte ?'**
  String get deleteAccountConfirm;

  /// No description provided for @irreversibleAction.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get irreversibleAction;

  /// No description provided for @addIncome.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un revenu'**
  String get addIncome;

  /// No description provided for @addExpense.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une dépense'**
  String get addExpense;

  /// No description provided for @title.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get title;

  /// No description provided for @required.
  ///
  /// In fr, this message translates to:
  /// **'Requis'**
  String get required;

  /// No description provided for @amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get amount;

  /// No description provided for @invalidNumber.
  ///
  /// In fr, this message translates to:
  /// **'Nombre invalide'**
  String get invalidNumber;

  /// No description provided for @category.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get category;

  /// No description provided for @pleaseChooseCategory.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez choisir une catégorie'**
  String get pleaseChooseCategory;

  /// No description provided for @linkedAccountOptional.
  ///
  /// In fr, this message translates to:
  /// **'Compte associé (Optionnel)'**
  String get linkedAccountOptional;

  /// No description provided for @noAccount.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte'**
  String get noAccount;

  /// No description provided for @date.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @saveIncome.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le revenu'**
  String get saveIncome;

  /// No description provided for @saveExpense.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la dépense'**
  String get saveExpense;

  /// No description provided for @finishReorder.
  ///
  /// In fr, this message translates to:
  /// **'Terminer la réorganisation'**
  String get finishReorder;

  /// No description provided for @reorderOperations.
  ///
  /// In fr, this message translates to:
  /// **'Réorganiser les opérations'**
  String get reorderOperations;

  /// No description provided for @noOperationForOperator.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération pour cet opérateur.'**
  String get noOperationForOperator;

  /// No description provided for @editOperation.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'opération'**
  String get editOperation;

  /// No description provided for @operationName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'opération'**
  String get operationName;

  /// No description provided for @ussdCodeExample.
  ///
  /// In fr, this message translates to:
  /// **'Code USSD (ex: *126#)'**
  String get ussdCodeExample;

  /// No description provided for @recipientNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro du destinataire'**
  String get recipientNumber;

  /// No description provided for @amountToTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Montant à transférer ({currency})'**
  String amountToTransfer(String currency);

  /// No description provided for @merchantCode.
  ///
  /// In fr, this message translates to:
  /// **'Code marchand'**
  String get merchantCode;

  /// No description provided for @limitPerOperation.
  ///
  /// In fr, this message translates to:
  /// **'Plafond : 500 000 {currency} par opération'**
  String limitPerOperation(String currency);

  /// No description provided for @feeFlat3333.
  ///
  /// In fr, this message translates to:
  /// **'54 {currency} forfaitaires'**
  String feeFlat3333(String currency);

  /// No description provided for @feePercent266666.
  ///
  /// In fr, this message translates to:
  /// **'1,5 % + 4 {currency} (droit fixe)'**
  String feePercent266666(String currency);

  /// No description provided for @feeFlatMax.
  ///
  /// In fr, this message translates to:
  /// **'4 004 {currency} forfaitaires'**
  String feeFlatMax(String currency);

  /// No description provided for @enterAmountToSeeFees.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant pour voir le détail des frais'**
  String get enterAmountToSeeFees;

  /// No description provided for @feesBreakdown.
  ///
  /// In fr, this message translates to:
  /// **'Détail des frais'**
  String get feesBreakdown;

  /// No description provided for @amountToSend.
  ///
  /// In fr, this message translates to:
  /// **'Montant à envoyer'**
  String get amountToSend;

  /// No description provided for @withdrawalFees.
  ///
  /// In fr, this message translates to:
  /// **'Frais de retrait ({label})'**
  String withdrawalFees(String label);

  /// No description provided for @ttaTax.
  ///
  /// In fr, this message translates to:
  /// **'TTA (0,2 % — loi finances 2022)'**
  String get ttaTax;

  /// No description provided for @totalFees.
  ///
  /// In fr, this message translates to:
  /// **'Total frais'**
  String get totalFees;

  /// No description provided for @amountDebited.
  ///
  /// In fr, this message translates to:
  /// **'Montant débité'**
  String get amountDebited;

  /// No description provided for @operatorLabel.
  ///
  /// In fr, this message translates to:
  /// **'Opérateur : {name}'**
  String operatorLabel(String name);

  /// No description provided for @fieldRequired.
  ///
  /// In fr, this message translates to:
  /// **'Ce champ est requis'**
  String get fieldRequired;

  /// No description provided for @pleaseEnterValidAmount.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir un montant valide'**
  String get pleaseEnterValidAmount;

  /// No description provided for @regulatoryLimitExceeded.
  ///
  /// In fr, this message translates to:
  /// **'Le plafond réglementaire est de 500 000 {currency} par opération'**
  String regulatoryLimitExceeded(String currency);

  /// No description provided for @includeWithdrawalFees.
  ///
  /// In fr, this message translates to:
  /// **'Inclure les frais de retrait'**
  String get includeWithdrawalFees;

  /// No description provided for @buyForAnother.
  ///
  /// In fr, this message translates to:
  /// **'Acheter pour un autre'**
  String get buyForAnother;

  /// No description provided for @executeOperation.
  ///
  /// In fr, this message translates to:
  /// **'Exécuter l\'opération'**
  String get executeOperation;

  /// No description provided for @allLabel.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get allLabel;

  /// No description provided for @noHistory.
  ///
  /// In fr, this message translates to:
  /// **'Aucun historique.'**
  String get noHistory;

  /// No description provided for @noHistoryForOperator.
  ///
  /// In fr, this message translates to:
  /// **'Aucun historique pour {operator}.'**
  String noHistoryForOperator(String operator);

  /// No description provided for @sortBy.
  ///
  /// In fr, this message translates to:
  /// **'Trier par'**
  String get sortBy;

  /// No description provided for @sortByDate.
  ///
  /// In fr, this message translates to:
  /// **'Trier par date'**
  String get sortByDate;

  /// No description provided for @sortByOperator.
  ///
  /// In fr, this message translates to:
  /// **'Trier par opérateur'**
  String get sortByOperator;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Effacer l\'historique ?'**
  String get clearHistoryConfirm;

  /// No description provided for @clearLabel.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get clearLabel;

  /// No description provided for @deleteEntryConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'entrée ?'**
  String get deleteEntryConfirm;

  /// No description provided for @deleteEntryWarning.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer cette ligne de l\'historique ?'**
  String get deleteEntryWarning;

  /// No description provided for @historyDate.
  ///
  /// In fr, this message translates to:
  /// **'Date : {date}'**
  String historyDate(String date);

  /// No description provided for @historyCode.
  ///
  /// In fr, this message translates to:
  /// **'Code : {code}'**
  String historyCode(String code);

  /// No description provided for @profile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @editProfileInfo.
  ///
  /// In fr, this message translates to:
  /// **'Modifier les informations'**
  String get editProfileInfo;

  /// No description provided for @firstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get lastName;

  /// No description provided for @myOperators.
  ///
  /// In fr, this message translates to:
  /// **'Mes Opérateurs'**
  String get myOperators;

  /// No description provided for @statistics.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get statistics;

  /// No description provided for @configuredOperations.
  ///
  /// In fr, this message translates to:
  /// **'Opérations configurées'**
  String get configuredOperations;

  /// No description provided for @scanMerchantCode.
  ///
  /// In fr, this message translates to:
  /// **'Scanner le code marchand'**
  String get scanMerchantCode;

  /// No description provided for @placeQrCodeInFrame.
  ///
  /// In fr, this message translates to:
  /// **'Placez le QR code dans le cadre'**
  String get placeQrCodeInFrame;

  /// No description provided for @optionalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Optionnel'**
  String get optionalLabel;

  /// No description provided for @variablesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Variables (séparées par des virgules, ex: contact, amount)'**
  String get variablesLabel;

  /// No description provided for @recentOperations.
  ///
  /// In fr, this message translates to:
  /// **'Actions récentes'**
  String get recentOperations;

  /// No description provided for @incomeCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories Revenus'**
  String get incomeCategories;

  /// No description provided for @addIncomeCategory.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une catégorie de revenu'**
  String get addIncomeCategory;

  /// No description provided for @debtsAndReceivables.
  ///
  /// In fr, this message translates to:
  /// **'Dettes & Créances'**
  String get debtsAndReceivables;

  /// No description provided for @debts.
  ///
  /// In fr, this message translates to:
  /// **'Dettes'**
  String get debts;

  /// No description provided for @receivables.
  ///
  /// In fr, this message translates to:
  /// **'Créances'**
  String get receivables;

  /// No description provided for @totalDebts.
  ///
  /// In fr, this message translates to:
  /// **'Total Dettes'**
  String get totalDebts;

  /// No description provided for @totalReceivables.
  ///
  /// In fr, this message translates to:
  /// **'Total Créances'**
  String get totalReceivables;

  /// No description provided for @debtTag.
  ///
  /// In fr, this message translates to:
  /// **'Contact / Titulaire'**
  String get debtTag;

  /// No description provided for @addDebtTag.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contact'**
  String get addDebtTag;

  /// No description provided for @debtBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde'**
  String get debtBalance;

  /// No description provided for @recentDebtOperations.
  ///
  /// In fr, this message translates to:
  /// **'Dernières opérations'**
  String get recentDebtOperations;

  /// No description provided for @noDebtTags.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact défini'**
  String get noDebtTags;

  /// No description provided for @deleteDebtConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce contact et toutes ses opérations ?'**
  String get deleteDebtConfirm;

  /// No description provided for @linkToCashFlow.
  ///
  /// In fr, this message translates to:
  /// **'Lier à un compte'**
  String get linkToCashFlow;

  /// No description provided for @linkToCashFlowDescription.
  ///
  /// In fr, this message translates to:
  /// **'Impacte le solde du compte (encaissement ou sortie d\'argent).'**
  String get linkToCashFlowDescription;

  /// No description provided for @addDebtOperation.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une dette'**
  String get addDebtOperation;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @filterActiveDebts.
  ///
  /// In fr, this message translates to:
  /// **'Actifs'**
  String get filterActiveDebts;

  /// No description provided for @filterOnlyDebts.
  ///
  /// In fr, this message translates to:
  /// **'Dettes'**
  String get filterOnlyDebts;

  /// No description provided for @filterOnlyReceivables.
  ///
  /// In fr, this message translates to:
  /// **'Créances'**
  String get filterOnlyReceivables;

  /// No description provided for @filterSettled.
  ///
  /// In fr, this message translates to:
  /// **'Soldés'**
  String get filterSettled;

  /// No description provided for @themeColor.
  ///
  /// In fr, this message translates to:
  /// **'Couleur du thème'**
  String get themeColor;

  /// No description provided for @saveAsExpense.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer comme dépense'**
  String get saveAsExpense;

  /// No description provided for @onboardingWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur FIMUS'**
  String get onboardingWelcome;

  /// No description provided for @onboardingStep1.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez votre langue'**
  String get onboardingStep1;

  /// No description provided for @onboardingStep2.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre pays'**
  String get onboardingStep2;

  /// No description provided for @onboardingStep3.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez votre profil'**
  String get onboardingStep3;

  /// No description provided for @onboardingStep4.
  ///
  /// In fr, this message translates to:
  /// **'Activer les notifications'**
  String get onboardingStep4;

  /// No description provided for @onboardingNotificationExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Si vous partagez un compte de dépenses ou une dette avec un proche, les notifications vous seront très utiles'**
  String get onboardingNotificationExplanation;

  /// No description provided for @onboardingEnableNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser les notifications'**
  String get onboardingEnableNotifications;

  /// No description provided for @onboardingNotificationsEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Notifications autorisées'**
  String get onboardingNotificationsEnabled;

  /// No description provided for @onboardingSkip.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get onboardingSkip;

  /// No description provided for @onboardingContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get onboardingContinue;

  /// No description provided for @onboardingFinish.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get onboardingFinish;

  /// No description provided for @onboardingNotifHeader.
  ///
  /// In fr, this message translates to:
  /// **'Restez informé en temps réel'**
  String get onboardingNotifHeader;

  /// No description provided for @onboardingNotifSub.
  ///
  /// In fr, this message translates to:
  /// **'Ne manquez aucun remboursement, suivi de compte ou alerte importante.'**
  String get onboardingNotifSub;

  /// No description provided for @onboardingNotifBenefit1Title.
  ///
  /// In fr, this message translates to:
  /// **'Rappels de dettes & échéances'**
  String get onboardingNotifBenefit1Title;

  /// No description provided for @onboardingNotifBenefit1Desc.
  ///
  /// In fr, this message translates to:
  /// **'Recevez un rappel automatique avant la date limite de remboursement.'**
  String get onboardingNotifBenefit1Desc;

  /// No description provided for @onboardingNotifBenefit2Title.
  ///
  /// In fr, this message translates to:
  /// **'Activité des comptes partagés'**
  String get onboardingNotifBenefit2Title;

  /// No description provided for @onboardingNotifBenefit2Desc.
  ///
  /// In fr, this message translates to:
  /// **'Soyez averti dès qu\'un proche ajoute ou modifie une dépense.'**
  String get onboardingNotifBenefit2Desc;

  /// No description provided for @onboardingNotifBenefit3Title.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité & confirmation USSD'**
  String get onboardingNotifBenefit3Title;

  /// No description provided for @onboardingNotifBenefit3Desc.
  ///
  /// In fr, this message translates to:
  /// **'Gardez un contrôle total sur la validation de vos transactions.'**
  String get onboardingNotifBenefit3Desc;

  /// No description provided for @home.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get home;

  /// No description provided for @addIncomeAction.
  ///
  /// In fr, this message translates to:
  /// **'+ Revenu'**
  String get addIncomeAction;

  /// No description provided for @addBorrowAction.
  ///
  /// In fr, this message translates to:
  /// **'+ Emprunt'**
  String get addBorrowAction;

  /// No description provided for @addAccountAction.
  ///
  /// In fr, this message translates to:
  /// **'+ Compte'**
  String get addAccountAction;

  /// No description provided for @addExpenseAction.
  ///
  /// In fr, this message translates to:
  /// **'+ Dépense'**
  String get addExpenseAction;

  /// No description provided for @addLendAction.
  ///
  /// In fr, this message translates to:
  /// **'+ Prêt'**
  String get addLendAction;

  /// No description provided for @myContacts.
  ///
  /// In fr, this message translates to:
  /// **'Mes contacts'**
  String get myContacts;

  /// No description provided for @noContactSaved.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact enregistré'**
  String get noContactSaved;

  /// No description provided for @addContactsExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des contacts pour partager des comptes et gérer des dettes en commun.'**
  String get addContactsExplanation;

  /// No description provided for @pseudoTag.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo : {code}'**
  String pseudoTag(String code);

  /// No description provided for @deleteContact.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le contact'**
  String get deleteContact;

  /// No description provided for @deleteContactConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer {name} de vos contacts ?'**
  String deleteContactConfirm(String name);

  /// No description provided for @contactHasActiveDebts.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez des dettes en cours avec ce {contact}'**
  String contactHasActiveDebts(String contact);

  /// No description provided for @createdBy.
  ///
  /// In fr, this message translates to:
  /// **'Par {name}'**
  String createdBy(String name);

  /// No description provided for @contactDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Contact supprimé'**
  String get contactDeleted;

  /// No description provided for @errorOccurred.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur s\'est produite'**
  String get errorOccurred;

  /// No description provided for @shareAccount.
  ///
  /// In fr, this message translates to:
  /// **'Partager \"{name}\"'**
  String shareAccount(String name);

  /// No description provided for @accountMembers.
  ///
  /// In fr, this message translates to:
  /// **'Membres de \"{name}\"'**
  String accountMembers(String name);

  /// No description provided for @currentMembers.
  ///
  /// In fr, this message translates to:
  /// **'Membres actuels :'**
  String get currentMembers;

  /// No description provided for @unknown.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get unknown;

  /// No description provided for @shareWithContact.
  ///
  /// In fr, this message translates to:
  /// **'Partager avec un contact :'**
  String get shareWithContact;

  /// No description provided for @noContactToShare.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez aucun contact. Ajoutez des contacts dans votre profil pour partager un compte.'**
  String get noContactToShare;

  /// No description provided for @sharingInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Partage en cours...'**
  String get sharingInProgress;

  /// No description provided for @accountSharedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Compte partagé avec {name} !'**
  String accountSharedSuccess(String name);

  /// No description provided for @shareImpossible.
  ///
  /// In fr, this message translates to:
  /// **'Partage impossible. Vérifiez votre connexion internet.'**
  String get shareImpossible;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @share.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get share;

  /// No description provided for @unknownAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte inconnu'**
  String get unknownAccount;

  /// No description provided for @accountNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Compte introuvable'**
  String get accountNotFound;

  /// No description provided for @untitled.
  ///
  /// In fr, this message translates to:
  /// **'Sans nom'**
  String get untitled;

  /// No description provided for @tooltipShareAccount.
  ///
  /// In fr, this message translates to:
  /// **'Partager le compte'**
  String get tooltipShareAccount;

  /// No description provided for @tooltipEditAccount.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le compte'**
  String get tooltipEditAccount;

  /// No description provided for @tooltipDeleteAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte'**
  String get tooltipDeleteAccount;

  /// No description provided for @tooltipViewMembers.
  ///
  /// In fr, this message translates to:
  /// **'Voir les membres'**
  String get tooltipViewMembers;

  /// No description provided for @accountBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde du compte'**
  String get accountBalance;

  /// No description provided for @sharedAccountBadge.
  ///
  /// In fr, this message translates to:
  /// **'En commun'**
  String get sharedAccountBadge;

  /// No description provided for @sharedByBadge.
  ///
  /// In fr, this message translates to:
  /// **'Partagé par {name}'**
  String sharedByBadge(String name);

  /// No description provided for @noOperationOnAccount.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération sur ce compte'**
  String get noOperationOnAccount;

  /// No description provided for @newContact.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contact'**
  String get newContact;

  /// No description provided for @installmentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Échéance {current}/{total}'**
  String installmentTitle(String current, String total);

  /// No description provided for @debtRepayment.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement de dette'**
  String get debtRepayment;

  /// No description provided for @collectReceivable.
  ///
  /// In fr, this message translates to:
  /// **'Encaisser une créance'**
  String get collectReceivable;

  /// No description provided for @newReceivable.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle créance'**
  String get newReceivable;

  /// No description provided for @newDebt.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle dette'**
  String get newDebt;

  /// No description provided for @collectMoney.
  ///
  /// In fr, this message translates to:
  /// **'Encaisser (Entrée d\'argent)'**
  String get collectMoney;

  /// No description provided for @repayMoney.
  ///
  /// In fr, this message translates to:
  /// **'Rembourser (Sortie d\'argent)'**
  String get repayMoney;

  /// No description provided for @receivableToCollect.
  ///
  /// In fr, this message translates to:
  /// **'Créance (Vous devez percevoir)'**
  String get receivableToCollect;

  /// No description provided for @debtToRepay.
  ///
  /// In fr, this message translates to:
  /// **'Dette (Vous devez rembourser)'**
  String get debtToRepay;

  /// No description provided for @interestDebtSimulator.
  ///
  /// In fr, this message translates to:
  /// **'Dette avec intérêt (Simulateur)'**
  String get interestDebtSimulator;

  /// No description provided for @interestDebtSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Calculer et planifier les échéances de remboursement automatiquement'**
  String get interestDebtSubtitle;

  /// No description provided for @creditDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails du crédit'**
  String get creditDetails;

  /// No description provided for @interestRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'intérêt'**
  String get interestRate;

  /// No description provided for @periodicity.
  ///
  /// In fr, this message translates to:
  /// **'Périodicité'**
  String get periodicity;

  /// No description provided for @annual.
  ///
  /// In fr, this message translates to:
  /// **'Annuel'**
  String get annual;

  /// No description provided for @monthly.
  ///
  /// In fr, this message translates to:
  /// **'Mensuel'**
  String get monthly;

  /// No description provided for @weekly.
  ///
  /// In fr, this message translates to:
  /// **'Hebdomadaire'**
  String get weekly;

  /// No description provided for @daily.
  ///
  /// In fr, this message translates to:
  /// **'Quotidien'**
  String get daily;

  /// No description provided for @duration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get duration;

  /// No description provided for @unit.
  ///
  /// In fr, this message translates to:
  /// **'Unité'**
  String get unit;

  /// No description provided for @months.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get months;

  /// No description provided for @years.
  ///
  /// In fr, this message translates to:
  /// **'Années'**
  String get years;

  /// No description provided for @repaymentFrequency.
  ///
  /// In fr, this message translates to:
  /// **'Fréquence de remboursement'**
  String get repaymentFrequency;

  /// No description provided for @amountPerInstallment.
  ///
  /// In fr, this message translates to:
  /// **'Montant par échéance'**
  String get amountPerInstallment;

  /// No description provided for @concernedAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte concerné *'**
  String get concernedAccount;

  /// No description provided for @selectAccount.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un compte'**
  String get selectAccount;

  /// No description provided for @addComment.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un commentaire'**
  String get addComment;

  /// No description provided for @commentOptional.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire (optionnel)'**
  String get commentOptional;

  /// No description provided for @variableAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get variableAmount;

  /// No description provided for @variableNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro'**
  String get variableNumber;

  /// No description provided for @variableMerchantCode.
  ///
  /// In fr, this message translates to:
  /// **'Code Marchand'**
  String get variableMerchantCode;

  /// No description provided for @noTransaction.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction'**
  String get noTransaction;

  /// No description provided for @expectedDueDate.
  ///
  /// In fr, this message translates to:
  /// **'Échéance prévue'**
  String get expectedDueDate;

  /// No description provided for @memo.
  ///
  /// In fr, this message translates to:
  /// **'Mémo'**
  String get memo;

  /// No description provided for @createdByName.
  ///
  /// In fr, this message translates to:
  /// **'Créé par {name}'**
  String createdByName(String name);

  /// No description provided for @borrowAction.
  ///
  /// In fr, this message translates to:
  /// **'Emprunt'**
  String get borrowAction;

  /// No description provided for @borrowSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer une dette que vous avez contractée'**
  String get borrowSubtitle;

  /// No description provided for @lendAction.
  ///
  /// In fr, this message translates to:
  /// **'Créance'**
  String get lendAction;

  /// No description provided for @lendSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'L\'argent que vous percevrez'**
  String get lendSubtitle;

  /// No description provided for @repaymentAction.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement'**
  String get repaymentAction;

  /// No description provided for @noDebtOrReceivableRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Aucune dette ou créance enregistrée pour le moment.'**
  String get noDebtOrReceivableRecorded;

  /// No description provided for @toRepay.
  ///
  /// In fr, this message translates to:
  /// **'À rembourser'**
  String get toRepay;

  /// No description provided for @totalToCollect.
  ///
  /// In fr, this message translates to:
  /// **'Total à percevoir'**
  String get totalToCollect;

  /// No description provided for @noRecentOperation.
  ///
  /// In fr, this message translates to:
  /// **'Aucune opération récente'**
  String get noRecentOperation;

  /// No description provided for @rejectDebt.
  ///
  /// In fr, this message translates to:
  /// **'Refuser la dette'**
  String get rejectDebt;

  /// No description provided for @rejectDebtConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer cette dette ? Cette action est irréversible et retirera votre nom de cette opération.'**
  String get rejectDebtConfirm;

  /// No description provided for @forgotPin.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN oublié ?'**
  String get forgotPin;

  /// No description provided for @forgotPinConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Pour déverrouiller l\'application sans votre PIN, vous devez vous déconnecter. Toutes les données non synchronisées seront conservées localement.'**
  String get forgotPinConfirm;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get logout;

  /// No description provided for @setPin.
  ///
  /// In fr, this message translates to:
  /// **'Définir un PIN'**
  String get setPin;

  /// No description provided for @confirmPin.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le PIN'**
  String get confirmPin;

  /// No description provided for @verifyPin.
  ///
  /// In fr, this message translates to:
  /// **'Vérification du PIN'**
  String get verifyPin;

  /// No description provided for @useBiometrics.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser l\'empreinte / Face ID'**
  String get useBiometrics;

  /// No description provided for @username.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get username;

  /// No description provided for @pleaseEnterUsername.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer un pseudo'**
  String get pleaseEnterUsername;

  /// No description provided for @pleaseFillAllFields.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez remplir tous les champs'**
  String get pleaseFillAllFields;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer un email valide'**
  String get pleaseEnterValidEmail;

  /// No description provided for @forgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordInstruction.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre adresse email pour recevoir un nouveau mot de passe.'**
  String get forgotPasswordInstruction;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailOrUsername.
  ///
  /// In fr, this message translates to:
  /// **'Email ou pseudo'**
  String get emailOrUsername;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get password;

  /// No description provided for @continueWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get continueWithGoogle;

  /// No description provided for @noNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification.'**
  String get noNotifications;

  /// No description provided for @notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @officialLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue officielle'**
  String get officialLanguage;

  /// No description provided for @defaultLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue par défaut'**
  String get defaultLanguage;

  /// No description provided for @individualProfile.
  ///
  /// In fr, this message translates to:
  /// **'Particulier'**
  String get individualProfile;

  /// No description provided for @personalManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion personnelle'**
  String get personalManagement;

  /// No description provided for @mobileAgentProfile.
  ///
  /// In fr, this message translates to:
  /// **'Agent Mobile'**
  String get mobileAgentProfile;

  /// No description provided for @kioskFleetProfile.
  ///
  /// In fr, this message translates to:
  /// **'Kiosque & Flotte'**
  String get kioskFleetProfile;

  /// No description provided for @editUsername.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'identifiant'**
  String get editUsername;

  /// No description provided for @editUsernameNotice.
  ///
  /// In fr, this message translates to:
  /// **'Votre identifiant doit être unique. S\'il est modifié avec succès, vos contacts seront notifiés.'**
  String get editUsernameNotice;

  /// No description provided for @newUsername.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel identifiant (Pseudo)'**
  String get newUsername;

  /// No description provided for @usernameUpdatedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant modifié avec succès !'**
  String get usernameUpdatedSuccess;

  /// No description provided for @newPinCode.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code PIN'**
  String get newPinCode;

  /// No description provided for @confirmPinCode.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le code PIN'**
  String get confirmPinCode;

  /// No description provided for @pinLockActivated.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage activé avec succès'**
  String get pinLockActivated;

  /// No description provided for @activate.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get activate;

  /// No description provided for @currentPinCode.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN actuel'**
  String get currentPinCode;

  /// No description provided for @pinLockDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage désactivé'**
  String get pinLockDisabled;

  /// No description provided for @incorrectPinCode.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN incorrect'**
  String get incorrectPinCode;

  /// No description provided for @disable.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver'**
  String get disable;

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccount;

  /// No description provided for @confirmPassword.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get passwordsDoNotMatch;

  /// No description provided for @welcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue'**
  String get welcome;

  /// No description provided for @login.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get login;

  /// No description provided for @addAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un compte'**
  String get addAccountTitle;

  /// No description provided for @accountNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom du compte'**
  String get accountNameLabel;

  /// No description provided for @accountColor.
  ///
  /// In fr, this message translates to:
  /// **'Couleur du compte'**
  String get accountColor;

  /// No description provided for @pleaseEnterName.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir un nom'**
  String get pleaseEnterName;

  /// No description provided for @addContactTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un contact'**
  String get addContactTitle;

  /// No description provided for @userCodeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code utilisateur (ex: USR-12345)'**
  String get userCodeLabel;

  /// No description provided for @search.
  ///
  /// In fr, this message translates to:
  /// **'Chercher'**
  String get search;

  /// No description provided for @addToContacts.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux contacts'**
  String get addToContacts;

  /// No description provided for @contactNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Contact introuvable'**
  String get contactNotFound;

  /// No description provided for @searchCountryHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un pays...'**
  String get searchCountryHint;

  /// No description provided for @noCountryFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun pays trouvé'**
  String get noCountryFound;

  /// No description provided for @catExpenseFood.
  ///
  /// In fr, this message translates to:
  /// **'Alimentation'**
  String get catExpenseFood;

  /// No description provided for @catExpenseTransport.
  ///
  /// In fr, this message translates to:
  /// **'Transport'**
  String get catExpenseTransport;

  /// No description provided for @catExpenseLeisure.
  ///
  /// In fr, this message translates to:
  /// **'Loisirs'**
  String get catExpenseLeisure;

  /// No description provided for @catExpenseHealth.
  ///
  /// In fr, this message translates to:
  /// **'Santé'**
  String get catExpenseHealth;

  /// No description provided for @catExpenseBills.
  ///
  /// In fr, this message translates to:
  /// **'Factures'**
  String get catExpenseBills;

  /// No description provided for @catExpenseOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get catExpenseOther;

  /// No description provided for @catIncomeSalary.
  ///
  /// In fr, this message translates to:
  /// **'Salaires'**
  String get catIncomeSalary;

  /// No description provided for @catIncomePension.
  ///
  /// In fr, this message translates to:
  /// **'Pension retraite'**
  String get catIncomePension;

  /// No description provided for @catIncomeFees.
  ///
  /// In fr, this message translates to:
  /// **'Honoraires'**
  String get catIncomeFees;

  /// No description provided for @catIncomeProfits.
  ///
  /// In fr, this message translates to:
  /// **'Bénéfices'**
  String get catIncomeProfits;

  /// No description provided for @catIncomeDividends.
  ///
  /// In fr, this message translates to:
  /// **'Dividendes'**
  String get catIncomeDividends;

  /// No description provided for @catIncomeSale.
  ///
  /// In fr, this message translates to:
  /// **'Vente de bien'**
  String get catIncomeSale;

  /// No description provided for @catIncomeDonations.
  ///
  /// In fr, this message translates to:
  /// **'Dons'**
  String get catIncomeDonations;

  /// No description provided for @catIncomeInheritance.
  ///
  /// In fr, this message translates to:
  /// **'Héritages'**
  String get catIncomeInheritance;

  /// No description provided for @catIncomeOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get catIncomeOther;

  /// No description provided for @catUssdDeposit.
  ///
  /// In fr, this message translates to:
  /// **'Dépôt'**
  String get catUssdDeposit;

  /// No description provided for @catUssdWithdrawal.
  ///
  /// In fr, this message translates to:
  /// **'Retrait'**
  String get catUssdWithdrawal;

  /// No description provided for @catUssdTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get catUssdTransfer;

  /// No description provided for @catUssdMerchantPayment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement marchand'**
  String get catUssdMerchantPayment;

  /// No description provided for @catUssdCredit.
  ///
  /// In fr, this message translates to:
  /// **'Crédit'**
  String get catUssdCredit;

  /// No description provided for @catUssdBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde'**
  String get catUssdBalance;

  /// No description provided for @catUssdInternet.
  ///
  /// In fr, this message translates to:
  /// **'Internet'**
  String get catUssdInternet;

  /// No description provided for @catUssdOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get catUssdOther;

  /// No description provided for @ussdActionCashIn.
  ///
  /// In fr, this message translates to:
  /// **'Dépôt d\'argent (Cash-In)'**
  String get ussdActionCashIn;

  /// No description provided for @ussdActionCashOutAgent.
  ///
  /// In fr, this message translates to:
  /// **'Retrait client (Cash-Out Agent)'**
  String get ussdActionCashOutAgent;

  /// No description provided for @ussdActionCashOutClient.
  ///
  /// In fr, this message translates to:
  /// **'Retrait d\'argent (Code client)'**
  String get ussdActionCashOutClient;

  /// No description provided for @ussdActionTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert d\'argent'**
  String get ussdActionTransfer;

  /// No description provided for @ussdActionMerchant.
  ///
  /// In fr, this message translates to:
  /// **'Paiement marchand'**
  String get ussdActionMerchant;

  /// No description provided for @ussdActionBalanceAgent.
  ///
  /// In fr, this message translates to:
  /// **'Solde compte Agent/UV'**
  String get ussdActionBalanceAgent;

  /// No description provided for @ussdActionCredit.
  ///
  /// In fr, this message translates to:
  /// **'Achat crédit'**
  String get ussdActionCredit;

  /// No description provided for @ussdActionCashInAgent.
  ///
  /// In fr, this message translates to:
  /// **'Dépôt d\'argent (Cash-In Agent)'**
  String get ussdActionCashInAgent;

  /// No description provided for @ussdActionBalanceFleet.
  ///
  /// In fr, this message translates to:
  /// **'Solde compte Flotte/Agent'**
  String get ussdActionBalanceFleet;

  /// No description provided for @ussdActionInternet.
  ///
  /// In fr, this message translates to:
  /// **'Achat forfait Internet'**
  String get ussdActionInternet;

  /// No description provided for @resetPasswordBtn.
  ///
  /// In fr, this message translates to:
  /// **'RÉINITIALISER'**
  String get resetPasswordBtn;

  /// No description provided for @finalizeRegistration.
  ///
  /// In fr, this message translates to:
  /// **'Finalisation de l\'inscription'**
  String get finalizeRegistration;

  /// No description provided for @finalizeRegistrationDesc.
  ///
  /// In fr, this message translates to:
  /// **'Pour finaliser la création de votre compte via Google, veuillez renseigner les informations ci-dessous.'**
  String get finalizeRegistrationDesc;

  /// No description provided for @uniqueIdentifierDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ceci est votre identifiant unique sur FIMUS'**
  String get uniqueIdentifierDesc;

  /// No description provided for @accountType.
  ///
  /// In fr, this message translates to:
  /// **'Type de compte'**
  String get accountType;

  /// No description provided for @noAccountYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ? '**
  String get noAccountYet;

  /// No description provided for @registerNow.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get registerNow;

  /// No description provided for @fullName.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get fullName;

  /// No description provided for @pleaseSelectCountry.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner votre pays'**
  String get pleaseSelectCountry;

  /// No description provided for @min8Chars.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 8 caractères'**
  String get min8Chars;

  /// No description provided for @professionalProfile.
  ///
  /// In fr, this message translates to:
  /// **'Professionnel'**
  String get professionalProfile;

  /// No description provided for @enableLock.
  ///
  /// In fr, this message translates to:
  /// **'Activer le verrouillage'**
  String get enableLock;

  /// No description provided for @enableLockDesc.
  ///
  /// In fr, this message translates to:
  /// **'Définissez un code PIN à 4 chiffres pour sécuriser l\'accès.'**
  String get enableLockDesc;

  /// No description provided for @disableLock.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver le verrouillage'**
  String get disableLock;

  /// No description provided for @disableLockDesc.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir votre code PIN actuel pour désactiver le verrouillage.'**
  String get disableLockDesc;

  /// No description provided for @changePinCode.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le code PIN'**
  String get changePinCode;

  /// No description provided for @changePinCodeDesc.
  ///
  /// In fr, this message translates to:
  /// **'Changer votre code PIN à 4 chiffres'**
  String get changePinCodeDesc;

  /// No description provided for @pinCodeChangedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN modifié avec succès'**
  String get pinCodeChangedSuccess;

  /// No description provided for @incorrectCurrentPinCode.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN actuel incorrect'**
  String get incorrectCurrentPinCode;

  /// No description provided for @myUniqueId.
  ///
  /// In fr, this message translates to:
  /// **'Mon identifiant unique'**
  String get myUniqueId;

  /// No description provided for @uniqueIdCopied.
  ///
  /// In fr, this message translates to:
  /// **'Code unique copié !'**
  String get uniqueIdCopied;

  /// No description provided for @manageContactsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Gérer vos contacts pour le partage de comptes et dettes'**
  String get manageContactsDesc;

  /// No description provided for @syncNow.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser maintenant'**
  String get syncNow;

  /// No description provided for @syncNowDesc.
  ///
  /// In fr, this message translates to:
  /// **'Pousse vos données locales vers le cloud'**
  String get syncNowDesc;

  /// No description provided for @lockApp.
  ///
  /// In fr, this message translates to:
  /// **'Verrouiller l\'application'**
  String get lockApp;

  /// No description provided for @lockAppDesc.
  ///
  /// In fr, this message translates to:
  /// **'Sécuriser l\'accès avec un code PIN'**
  String get lockAppDesc;

  /// No description provided for @unlockWithBiometrics.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouiller avec la biométrie'**
  String get unlockWithBiometrics;

  /// No description provided for @errorMarkNotifRead.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: impossible de marquer la notification comme lue.'**
  String get errorMarkNotifRead;

  /// No description provided for @errorMarkAllNotifRead.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: impossible de marquer les notifications comme lues.'**
  String get errorMarkAllNotifRead;

  /// No description provided for @completeProfileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compléter votre profil'**
  String get completeProfileTitle;

  /// No description provided for @completeProfileSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Quelques informations supplémentaires sont requises'**
  String get completeProfileSubtitle;

  /// No description provided for @countryOfResidence.
  ///
  /// In fr, this message translates to:
  /// **'Pays de résidence'**
  String get countryOfResidence;

  /// No description provided for @selectCountry.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un pays'**
  String get selectCountry;

  /// No description provided for @pseudo.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get pseudo;

  /// No description provided for @pseudoExample.
  ///
  /// In fr, this message translates to:
  /// **'Ex: marc123'**
  String get pseudoExample;

  /// No description provided for @countryRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un pays'**
  String get countryRequired;

  /// No description provided for @finish.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get finish;

  /// No description provided for @pseudoRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir un pseudo'**
  String get pseudoRequired;

  /// No description provided for @pseudoLength.
  ///
  /// In fr, this message translates to:
  /// **'Le pseudo doit contenir entre 3 et 15 caractères'**
  String get pseudoLength;

  /// No description provided for @pseudoFormat.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les lettres, chiffres, tirets et tirets bas sont autorisés'**
  String get pseudoFormat;

  /// No description provided for @tooManyRequests.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Veuillez réessayer plus tard.'**
  String get tooManyRequests;

  /// No description provided for @tooManyRequestsRetry.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Veuillez réessayer dans {seconds} secondes.'**
  String tooManyRequestsRetry(String seconds);

  /// No description provided for @deleteUserAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteUserAccount;

  /// No description provided for @deleteUserAccountConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte'**
  String get deleteUserAccountConfirm;

  /// No description provided for @deleteUserAccountWarning.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer définitivement votre compte FIMUS ? Cette action est irréversible et supprimera l\'ensemble de vos données du serveur.'**
  String get deleteUserAccountWarning;

  /// No description provided for @accountDeletedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte a été supprimé avec succès.'**
  String get accountDeletedSuccess;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
