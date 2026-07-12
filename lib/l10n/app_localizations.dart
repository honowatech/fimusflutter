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
  /// **'Dashboard'**
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
  /// **'Dettes'**
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
  /// **'+ Nouveau contact'**
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
  /// **'Lier au flux de trésorerie ?'**
  String get linkToCashFlow;

  /// No description provided for @linkToCashFlowDescription.
  ///
  /// In fr, this message translates to:
  /// **'Si non, cette opération sera un simple mémo.'**
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
