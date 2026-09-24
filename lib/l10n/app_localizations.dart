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

  /// No description provided for @yesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get yesterday;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @errorFetchNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les notifications. Vérifiez votre connexion.'**
  String get errorFetchNotifications;

  /// No description provided for @errorDeleteNotif.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression.'**
  String get errorDeleteNotif;

  /// No description provided for @markAllAsReadTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer comme lu'**
  String get markAllAsReadTooltip;

  /// No description provided for @notifyAnnouncementsPref.
  ///
  /// In fr, this message translates to:
  /// **'Annonces et campagnes'**
  String get notifyAnnouncementsPref;

  /// No description provided for @notifyAnnouncementsPrefDesc.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir les messages d\'information envoyés par FIMUS.'**
  String get notifyAnnouncementsPrefDesc;

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
  /// **'Actions rapides'**
  String get recentOperations;

  /// No description provided for @last7Days.
  ///
  /// In fr, this message translates to:
  /// **'Les 7 derniers jours'**
  String get last7Days;

  /// No description provided for @incomeEntries.
  ///
  /// In fr, this message translates to:
  /// **'Entrées'**
  String get incomeEntries;

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

  /// No description provided for @notificationFallback.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle notification'**
  String get notificationFallback;

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
  /// **'Pension Retraite'**
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
  /// **'Vente De Bien'**
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

  /// No description provided for @myContacts.
  ///
  /// In fr, this message translates to:
  /// **'Mes contacts'**
  String get myContacts;

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

  /// No description provided for @tabOperations.
  ///
  /// In fr, this message translates to:
  /// **'Opérations'**
  String get tabOperations;

  /// No description provided for @tabBreakdown.
  ///
  /// In fr, this message translates to:
  /// **'Synthèse & Pôles'**
  String get tabBreakdown;

  /// No description provided for @spendingByPole.
  ///
  /// In fr, this message translates to:
  /// **'Répartition par pôle'**
  String get spendingByPole;

  /// No description provided for @spendingByMember.
  ///
  /// In fr, this message translates to:
  /// **'Répartition par membre'**
  String get spendingByMember;

  /// No description provided for @familyContributions.
  ///
  /// In fr, this message translates to:
  /// **'Contributions'**
  String get familyContributions;

  /// No description provided for @shareWithContacts.
  ///
  /// In fr, this message translates to:
  /// **'Partager avec des contacts'**
  String get shareWithContacts;

  /// No description provided for @selectContacts.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner des contacts'**
  String get selectContacts;

  /// No description provided for @noContactsSelected.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact sélectionné'**
  String get noContactsSelected;

  /// No description provided for @noContactFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact trouvé'**
  String get noContactFound;

  /// No description provided for @linkedContacts.
  ///
  /// In fr, this message translates to:
  /// **'Contacts associés'**
  String get linkedContacts;

  /// No description provided for @accountSharedSuccessMultiple.
  ///
  /// In fr, this message translates to:
  /// **'Compte partagé avec succès !'**
  String get accountSharedSuccessMultiple;

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous les pôles'**
  String get filterAll;

  /// No description provided for @periodMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois'**
  String get periodMonth;

  /// No description provided for @periodLastMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois dernier'**
  String get periodLastMonth;

  /// No description provided for @period30Days.
  ///
  /// In fr, this message translates to:
  /// **'30 derniers jours'**
  String get period30Days;

  /// No description provided for @periodYear.
  ///
  /// In fr, this message translates to:
  /// **'Cette année'**
  String get periodYear;

  /// No description provided for @periodCustom.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisé'**
  String get periodCustom;

  /// No description provided for @totalExpenses.
  ///
  /// In fr, this message translates to:
  /// **'Total dépenses'**
  String get totalExpenses;

  /// No description provided for @totalIncomes.
  ///
  /// In fr, this message translates to:
  /// **'Total recettes'**
  String get totalIncomes;

  /// No description provided for @netBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde net'**
  String get netBalance;

  /// No description provided for @noExpenseInPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Aucune dépense sur cette période'**
  String get noExpenseInPeriod;

  /// No description provided for @addContactsToShare.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des contacts'**
  String get addContactsToShare;

  /// No description provided for @selectedContactsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} contact(s) sélectionné(s)'**
  String selectedContactsCount(int count);

  /// No description provided for @profileTypeSection.
  ///
  /// In fr, this message translates to:
  /// **'Profil d\'utilisation'**
  String get profileTypeSection;

  /// No description provided for @currentProfileType.
  ///
  /// In fr, this message translates to:
  /// **'Type de profil actuel'**
  String get currentProfileType;

  /// No description provided for @switchToProfessional.
  ///
  /// In fr, this message translates to:
  /// **'Passer au profil Professionnel'**
  String get switchToProfessional;

  /// No description provided for @switchToPersonal.
  ///
  /// In fr, this message translates to:
  /// **'Passer au profil Personnel'**
  String get switchToPersonal;

  /// No description provided for @profileTypePermanent.
  ///
  /// In fr, this message translates to:
  /// **'Profil définitif'**
  String get profileTypePermanent;

  /// No description provided for @profileTypeAlreadyChanged.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà modifié votre profil. Ce choix est désormais irréversible.'**
  String get profileTypeAlreadyChanged;

  /// No description provided for @profileTypeOneTimeHint.
  ///
  /// In fr, this message translates to:
  /// **'Changement unique autorisé'**
  String get profileTypeOneTimeHint;

  /// No description provided for @profileChangeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Changer de profil ?'**
  String get profileChangeTitle;

  /// No description provided for @profileChangeToProfessionalDesc.
  ///
  /// In fr, this message translates to:
  /// **'En passant au profil Professionnel, vous aurez accès aux codes USSD Marchand / Agent, aux outils de tenue de caisse et de transactions commerciales.'**
  String get profileChangeToProfessionalDesc;

  /// No description provided for @profileChangeToPersonalDesc.
  ///
  /// In fr, this message translates to:
  /// **'En passant au profil Personnel, votre interface sera simplifiée et axée sur vos finances et dépenses personnelles.'**
  String get profileChangeToPersonalDesc;

  /// No description provided for @profileChangeWarning.
  ///
  /// In fr, this message translates to:
  /// **'Attention : cette action est définitive. Vous ne pourrez plus revenir au profil précédent après confirmation.'**
  String get profileChangeWarning;

  /// No description provided for @confirmProfileChange.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le changement'**
  String get confirmProfileChange;

  /// No description provided for @profileChangeSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Profil modifié avec succès'**
  String get profileChangeSuccess;

  /// No description provided for @profileChangeError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du changement de profil'**
  String get profileChangeError;

  /// No description provided for @announcements.
  ///
  /// In fr, this message translates to:
  /// **'Annonces'**
  String get announcements;

  /// No description provided for @enableNotificationsPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Activez les notifications pour ne rien manquer.'**
  String get enableNotificationsPrompt;

  /// No description provided for @batteryOptimizationPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Pour recevoir les rappels à l\'heure, autorisez FIMUS à ignorer l\'optimisation de batterie.'**
  String get batteryOptimizationPrompt;

  /// No description provided for @onboardingNotificationsDenied.
  ///
  /// In fr, this message translates to:
  /// **'Notifications non autorisées. Vous pourrez les activer plus tard dans les réglages.'**
  String get onboardingNotificationsDenied;

  /// No description provided for @notifyDebtsPref.
  ///
  /// In fr, this message translates to:
  /// **'Dettes et remboursements'**
  String get notifyDebtsPref;

  /// No description provided for @notifyDebtsPrefDesc.
  ///
  /// In fr, this message translates to:
  /// **'Alertes quand une dette partagée est créée, mise à jour ou refusée.'**
  String get notifyDebtsPrefDesc;

  /// No description provided for @notifyContactsPref.
  ///
  /// In fr, this message translates to:
  /// **'Contacts'**
  String get notifyContactsPref;

  /// No description provided for @notifyContactsPrefDesc.
  ///
  /// In fr, this message translates to:
  /// **'Alertes lorsqu\'un proche vous ajoute à ses contacts.'**
  String get notifyContactsPrefDesc;

  /// No description provided for @notifyJointAccountsPref.
  ///
  /// In fr, this message translates to:
  /// **'Comptes conjoints'**
  String get notifyJointAccountsPref;

  /// No description provided for @notifyJointAccountsPrefDesc.
  ///
  /// In fr, this message translates to:
  /// **'Alertes lorsqu\'on vous invite à un compte partagé.'**
  String get notifyJointAccountsPrefDesc;

  /// No description provided for @confirmAndRegister.
  ///
  /// In fr, this message translates to:
  /// **'CONFIRMER ET S\'INSCRIRE'**
  String get confirmAndRegister;

  /// No description provided for @suggestionsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Propositions :'**
  String get suggestionsLabel;

  /// No description provided for @unnamedContact.
  ///
  /// In fr, this message translates to:
  /// **'Un contact'**
  String get unnamedContact;

  /// No description provided for @debtDueNotifTitleDebt.
  ///
  /// In fr, this message translates to:
  /// **'⏰ Rappel d\'échéance : Dette'**
  String get debtDueNotifTitleDebt;

  /// No description provided for @debtDueNotifTitleReceivable.
  ///
  /// In fr, this message translates to:
  /// **'⏰ Rappel d\'échéance : Créance'**
  String get debtDueNotifTitleReceivable;

  /// No description provided for @debtDueNotifBodyDebt.
  ///
  /// In fr, this message translates to:
  /// **'Votre dette de {amount} {currency} envers {name} arrive à échéance aujourd\'hui.'**
  String debtDueNotifBodyDebt(String amount, String currency, String name);

  /// No description provided for @debtDueNotifBodyReceivable.
  ///
  /// In fr, this message translates to:
  /// **'Le remboursement de {amount} {currency} par {name} arrive à échéance aujourd\'hui.'**
  String debtDueNotifBodyReceivable(
    String amount,
    String currency,
    String name,
  );

  /// No description provided for @scheduledExpenseNotifTitle.
  ///
  /// In fr, this message translates to:
  /// **'⏰ Dépense programmée'**
  String get scheduledExpenseNotifTitle;

  /// No description provided for @scheduledExpenseNotifBody.
  ///
  /// In fr, this message translates to:
  /// **'« {title} » · {amount} {currency} — prévue à {time}. Touchez pour confirmer, modifier ou annuler.'**
  String scheduledExpenseNotifBody(
    String title,
    String amount,
    String currency,
    String time,
  );

  /// No description provided for @scheduledConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get scheduledConfirmAction;

  /// No description provided for @scheduledCancelAction.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get scheduledCancelAction;

  /// No description provided for @scheduledExpense.
  ///
  /// In fr, this message translates to:
  /// **'Dépense programmée'**
  String get scheduledExpense;

  /// No description provided for @scheduledLabel.
  ///
  /// In fr, this message translates to:
  /// **'Programmées'**
  String get scheduledLabel;

  /// No description provided for @addScheduledExpense.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une dépense programmée'**
  String get addScheduledExpense;

  /// No description provided for @editScheduledExpense.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la dépense programmée'**
  String get editScheduledExpense;

  /// No description provided for @scheduledExpenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses programmées'**
  String get scheduledExpenses;

  /// No description provided for @dateAndTime.
  ///
  /// In fr, this message translates to:
  /// **'Date et heure'**
  String get dateAndTime;

  /// No description provided for @confirmExpense.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la dépense'**
  String get confirmExpense;

  /// No description provided for @modify.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get modify;

  /// No description provided for @cancelScheduledExpense.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la dépense programmée'**
  String get cancelScheduledExpense;

  /// No description provided for @cancelScheduledExpenseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler cette programmation ?'**
  String get cancelScheduledExpenseTitle;

  /// No description provided for @cancelScheduledExpenseBody.
  ///
  /// In fr, this message translates to:
  /// **'La dépense programmée sera supprimée et vous ne serez plus notifié(e).'**
  String get cancelScheduledExpenseBody;

  /// No description provided for @futureDateRequired.
  ///
  /// In fr, this message translates to:
  /// **'La date et l\'heure doivent être dans le futur.'**
  String get futureDateRequired;

  /// No description provided for @scheduledExpensesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune dépense programmée pour le moment.'**
  String get scheduledExpensesEmpty;

  /// No description provided for @saveSchedule.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la programmation'**
  String get saveSchedule;

  /// No description provided for @scheduleSaved.
  ///
  /// In fr, this message translates to:
  /// **'Dépense programmée enregistrée. Vous serez notifié(e) à l\'échéance.'**
  String get scheduleSaved;

  /// No description provided for @scheduleUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Programmation mise à jour.'**
  String get scheduleUpdated;

  /// No description provided for @scheduledExpenseConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Dépense confirmée ✅'**
  String get scheduledExpenseConfirmed;

  /// No description provided for @scheduledExpenseCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Dépense programmée annulée'**
  String get scheduledExpenseCancelled;

  /// No description provided for @confirmNow.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer maintenant'**
  String get confirmNow;

  /// No description provided for @upcomingScheduledExpenses.
  ///
  /// In fr, this message translates to:
  /// **'{count} dépense(s) programmée(s)'**
  String upcomingScheduledExpenses(int count);

  /// No description provided for @scheduledOn.
  ///
  /// In fr, this message translates to:
  /// **'Prévue le : {date}'**
  String scheduledOn(String date);

  /// No description provided for @scheduledTodayAt.
  ///
  /// In fr, this message translates to:
  /// **'aujourd\'hui à {time}'**
  String scheduledTodayAt(String time);

  /// No description provided for @scheduledInDays.
  ///
  /// In fr, this message translates to:
  /// **'dans {days} jour(s)'**
  String scheduledInDays(int days);

  /// No description provided for @editExpense.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la dépense'**
  String get editExpense;

  /// No description provided for @editIncome.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le revenu'**
  String get editIncome;

  /// No description provided for @operationOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options de l\'opération'**
  String get operationOptions;

  /// No description provided for @detailsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détails de l\'opération'**
  String get detailsTitle;

  /// No description provided for @typeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @operationDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de l\'opération'**
  String get operationDate;

  /// No description provided for @recordedDate.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'enregistrement'**
  String get recordedDate;

  /// No description provided for @recordedBy.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrée par'**
  String get recordedBy;

  /// No description provided for @linkedAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte lié'**
  String get linkedAccount;

  /// No description provided for @noteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// No description provided for @noNote.
  ///
  /// In fr, this message translates to:
  /// **'Aucune note'**
  String get noNote;

  /// No description provided for @me.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get me;

  /// No description provided for @status.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get status;

  /// No description provided for @dueDateLabel.
  ///
  /// In fr, this message translates to:
  /// **'Échéance'**
  String get dueDateLabel;

  /// No description provided for @debtTagLabel.
  ///
  /// In fr, this message translates to:
  /// **'Personne concernée'**
  String get debtTagLabel;

  /// No description provided for @debtStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get debtStatusPending;

  /// No description provided for @debtStatusAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Acceptée'**
  String get debtStatusAccepted;

  /// No description provided for @sharedAccountOperationBy.
  ///
  /// In fr, this message translates to:
  /// **'Opération enregistrée sur ce compte partagé par {name}'**
  String sharedAccountOperationBy(String name);

  /// No description provided for @myAccount.
  ///
  /// In fr, this message translates to:
  /// **'Mon Compte'**
  String get myAccount;

  /// No description provided for @user.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get user;

  /// No description provided for @myPseudo.
  ///
  /// In fr, this message translates to:
  /// **'Mon pseudo'**
  String get myPseudo;

  /// No description provided for @notDefined.
  ///
  /// In fr, this message translates to:
  /// **'Non défini'**
  String get notDefined;

  /// No description provided for @pseudoCopied.
  ///
  /// In fr, this message translates to:
  /// **'Mon pseudo copié !'**
  String get pseudoCopied;

  /// No description provided for @syncComplete.
  ///
  /// In fr, this message translates to:
  /// **'Sync terminée — {pushed} envoyés, {pulled} reçus'**
  String syncComplete(int pushed, int pulled);

  /// No description provided for @syncError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {message}'**
  String syncError(String message);

  /// No description provided for @logoutTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get logoutTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir vous déconnecter ? Vos données locales seront préservées.'**
  String get logoutConfirmBody;

  /// No description provided for @loginToSync.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour synchroniser vos données dans le cloud.'**
  String get loginToSync;

  /// No description provided for @accessSecurity.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité d\'accès'**
  String get accessSecurity;

  /// No description provided for @fingerprintFaceId.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte / Face ID'**
  String get fingerprintFaceId;

  /// No description provided for @enter4Digits.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez 4 chiffres'**
  String get enter4Digits;

  /// No description provided for @pinCodesDoNotMatch.
  ///
  /// In fr, this message translates to:
  /// **'Les codes ne correspondent pas'**
  String get pinCodesDoNotMatch;

  /// No description provided for @pinRequired.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN requis'**
  String get pinRequired;

  /// No description provided for @environmentDevMode.
  ///
  /// In fr, this message translates to:
  /// **'Environnement & Mode Dev'**
  String get environmentDevMode;

  /// No description provided for @devModeLocalDb.
  ///
  /// In fr, this message translates to:
  /// **'Mode Développeur (BD Locale)'**
  String get devModeLocalDb;

  /// No description provided for @productionMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode Production (PlayStore)'**
  String get productionMode;

  /// No description provided for @connectedToLocalDb.
  ///
  /// In fr, this message translates to:
  /// **'Connecté à la base locale : {url}'**
  String connectedToLocalDb(String url);

  /// No description provided for @connectedToOnlineServer.
  ///
  /// In fr, this message translates to:
  /// **'Connecté au serveur en ligne sécurisé (PlayStore)'**
  String get connectedToOnlineServer;

  /// No description provided for @enableDevModeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activer le mode Dev ?'**
  String get enableDevModeTitle;

  /// No description provided for @enableDevModeBody.
  ///
  /// In fr, this message translates to:
  /// **'En mode Dev, l\'application se connecte à votre base de données locale (Laravel local) et isole les données dans monitrack_dev.db.\n\nVous pourrez repasser en mode Production à tout moment avant la publication PlayStore.'**
  String get enableDevModeBody;

  /// No description provided for @enableDevModeBtn.
  ///
  /// In fr, this message translates to:
  /// **'Activer Mode Dev'**
  String get enableDevModeBtn;

  /// No description provided for @localDbInfo.
  ///
  /// In fr, this message translates to:
  /// **'Base locale active: {db}\nURL API: {url}'**
  String localDbInfo(String db, String url);

  /// No description provided for @localEnvType.
  ///
  /// In fr, this message translates to:
  /// **'Type d\'environnement local :'**
  String get localEnvType;

  /// No description provided for @hostVhost.
  ///
  /// In fr, this message translates to:
  /// **'Host fimus.local (Recommandé)'**
  String get hostVhost;

  /// No description provided for @hostEmulator.
  ///
  /// In fr, this message translates to:
  /// **'Émulateur Android (10.0.2.2)'**
  String get hostEmulator;

  /// No description provided for @hostWeb.
  ///
  /// In fr, this message translates to:
  /// **'Localhost / Web'**
  String get hostWeb;

  /// No description provided for @hostCustom.
  ///
  /// In fr, this message translates to:
  /// **'IP / URL personnalisée'**
  String get hostCustom;

  /// No description provided for @localApiUrlLabel.
  ///
  /// In fr, this message translates to:
  /// **'URL de l\'API Locale (Serveur Laravel)'**
  String get localApiUrlLabel;

  /// No description provided for @localApiUrlHint.
  ///
  /// In fr, this message translates to:
  /// **'http://fimus.local/api ou http://192.168.1.50:8000/api'**
  String get localApiUrlHint;

  /// No description provided for @localApiUrlHelper.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez l\'adresse de votre serveur local (ex: http://fimus.local/api ou IP WiFi).'**
  String get localApiUrlHelper;

  /// No description provided for @testConnection.
  ///
  /// In fr, this message translates to:
  /// **'Tester la connexion'**
  String get testConnection;

  /// No description provided for @devHostApply.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get devHostApply;

  /// No description provided for @resetToLaunchProfile.
  ///
  /// In fr, this message translates to:
  /// **'Revenir au profil de lancement'**
  String get resetToLaunchProfile;

  /// No description provided for @connectionTestOk.
  ///
  /// In fr, this message translates to:
  /// **'Connexion réussie ({ms} ms)'**
  String connectionTestOk(int ms);

  /// No description provided for @connectionTestHttpStatus.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur a répondu avec le code {code}'**
  String connectionTestHttpStatus(int code);

  /// No description provided for @connectionTestTimeout.
  ///
  /// In fr, this message translates to:
  /// **'Délai dépassé (> 4 s). Vérifiez l\'URL ou le serveur.'**
  String get connectionTestTimeout;

  /// No description provided for @connectionTestRefused.
  ///
  /// In fr, this message translates to:
  /// **'Connexion refusée. Le serveur local est-il démarré ?'**
  String get connectionTestRefused;

  /// No description provided for @connectionTestError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String connectionTestError(String error);

  /// No description provided for @purgeTestDbTitle.
  ///
  /// In fr, this message translates to:
  /// **'Purger la base locale de test ?'**
  String get purgeTestDbTitle;

  /// No description provided for @purgeTestDbBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette action supprime les données de test de monitrack_dev.db. Votre base de production ne sera pas affectée.'**
  String get purgeTestDbBody;

  /// No description provided for @purge.
  ///
  /// In fr, this message translates to:
  /// **'Purger'**
  String get purge;

  /// No description provided for @purgeTests.
  ///
  /// In fr, this message translates to:
  /// **'Purger tests'**
  String get purgeTests;

  /// No description provided for @backToProduction.
  ///
  /// In fr, this message translates to:
  /// **'Retour Production'**
  String get backToProduction;

  /// No description provided for @allCategoriesSelected.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get allCategoriesSelected;

  /// No description provided for @categoriesSelectedCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} catégories'**
  String categoriesSelectedCount(int count);

  /// No description provided for @filterByCategory.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer par catégorie'**
  String get filterByCategory;

  /// No description provided for @accountsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Comptes connectés sur cet appareil'**
  String get accountsDesc;

  /// No description provided for @accountsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} comptes connectés'**
  String accountsCount(int count);

  /// No description provided for @addAccountSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez un autre compte MoniTrack sur cet appareil'**
  String get addAccountSubtitle;

  /// No description provided for @activeAccount.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get activeAccount;

  /// No description provided for @deviceAccountLimit.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez connecter jusqu\'à {max} comptes sur cet appareil. Déconnectez un compte pour en ajouter un autre.'**
  String deviceAccountLimit(int max);

  /// No description provided for @createCategory.
  ///
  /// In fr, this message translates to:
  /// **'Créer « {name} »'**
  String createCategory(String name);

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationSettingsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Autorisations, catégories et heures calmes'**
  String get notificationSettingsSubtitle;

  /// No description provided for @notificationPermissionSection.
  ///
  /// In fr, this message translates to:
  /// **'Autorisation système'**
  String get notificationPermissionSection;

  /// No description provided for @notificationPermissionGranted.
  ///
  /// In fr, this message translates to:
  /// **'Notifications autorisées'**
  String get notificationPermissionGranted;

  /// No description provided for @notificationPermissionGrantedDesc.
  ///
  /// In fr, this message translates to:
  /// **'FIMUS peut vous alerter en temps réel.'**
  String get notificationPermissionGrantedDesc;

  /// No description provided for @notificationPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Notifications bloquées'**
  String get notificationPermissionDenied;

  /// No description provided for @notificationPermissionDeniedDesc.
  ///
  /// In fr, this message translates to:
  /// **'Sans autorisation, les rappels d\'échéance et les alertes de dettes partagées ne s\'afficheront pas.'**
  String get notificationPermissionDeniedDesc;

  /// No description provided for @notificationPermissionUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Autorisation non vérifiée'**
  String get notificationPermissionUnknown;

  /// No description provided for @notificationPermissionUnknownDesc.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez l\'état de l\'autorisation pour recevoir les alertes.'**
  String get notificationPermissionUnknownDesc;

  /// No description provided for @notificationPermissionCheck.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier'**
  String get notificationPermissionCheck;

  /// No description provided for @notificationPermissionOpenSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get notificationPermissionOpenSettings;

  /// No description provided for @notificationPermissionSettingsHint.
  ///
  /// In fr, this message translates to:
  /// **'Le système ne redemandera plus. Activez les notifications depuis les réglages de l\'application.'**
  String get notificationPermissionSettingsHint;

  /// No description provided for @notificationPermissionRationaleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activer les notifications ?'**
  String get notificationPermissionRationaleTitle;

  /// No description provided for @notificationPermissionRationaleBody.
  ///
  /// In fr, this message translates to:
  /// **'FIMUS vous prévient à l\'échéance d\'une dette, quand un proche vous ajoute à un compte partagé et avant une dépense programmée. Aucune notification publicitaire n\'est envoyée sans votre accord.'**
  String get notificationPermissionRationaleBody;

  /// No description provided for @notificationPermissionRationaleConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser'**
  String get notificationPermissionRationaleConfirm;

  /// No description provided for @notificationPermissionRationaleDismiss.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get notificationPermissionRationaleDismiss;

  /// No description provided for @notificationCategoriesSection.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get notificationCategoriesSection;

  /// No description provided for @notifyScheduledExpensesPref.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses programmées'**
  String get notifyScheduledExpensesPref;

  /// No description provided for @notifyScheduledExpensesPrefDesc.
  ///
  /// In fr, this message translates to:
  /// **'Rappels avant le prélèvement d\'une dépense récurrente.'**
  String get notifyScheduledExpensesPrefDesc;

  /// No description provided for @reminderScheduleSection.
  ///
  /// In fr, this message translates to:
  /// **'Rappels'**
  String get reminderScheduleSection;

  /// No description provided for @reminderHourTitle.
  ///
  /// In fr, this message translates to:
  /// **'Heure des rappels'**
  String get reminderHourTitle;

  /// No description provided for @reminderHourDesc.
  ///
  /// In fr, this message translates to:
  /// **'Heure à laquelle les rappels d\'échéance sont envoyés.'**
  String get reminderHourDesc;

  /// No description provided for @quietHoursTitle.
  ///
  /// In fr, this message translates to:
  /// **'Heures calmes'**
  String get quietHoursTitle;

  /// No description provided for @quietHoursDesc.
  ///
  /// In fr, this message translates to:
  /// **'Suspendre les notifications pendant une plage horaire.'**
  String get quietHoursDesc;

  /// No description provided for @quietHoursStartLabel.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get quietHoursStartLabel;

  /// No description provided for @quietHoursEndLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get quietHoursEndLabel;

  /// No description provided for @quietHoursOvernightHint.
  ///
  /// In fr, this message translates to:
  /// **'La plage se poursuit après minuit.'**
  String get quietHoursOvernightHint;

  /// No description provided for @exactAlarmsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Alarmes exactes'**
  String get exactAlarmsTitle;

  /// No description provided for @exactAlarmsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Nécessaires pour déclencher les rappels à l\'heure précise. Sans elles, Android peut les retarder de plusieurs heures.'**
  String get exactAlarmsDesc;

  /// No description provided for @exactAlarmsGranted.
  ///
  /// In fr, this message translates to:
  /// **'Autorisées'**
  String get exactAlarmsGranted;

  /// No description provided for @exactAlarmsMissing.
  ///
  /// In fr, this message translates to:
  /// **'Non autorisées'**
  String get exactAlarmsMissing;

  /// No description provided for @exactAlarmsAllow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser'**
  String get exactAlarmsAllow;

  /// No description provided for @notificationPreferencesLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos préférences de notification.'**
  String get notificationPreferencesLoadError;

  /// No description provided for @notificationPreferencesSaveError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer la modification. Elle a été annulée.'**
  String get notificationPreferencesSaveError;

  /// No description provided for @notificationPreferencesOfflineHint.
  ///
  /// In fr, this message translates to:
  /// **'Valeurs enregistrées sur cet appareil, affichées hors connexion.'**
  String get notificationPreferencesOfflineHint;

  /// No description provided for @offlineBanner.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne · données locales'**
  String get offlineBanner;

  /// No description provided for @offlineBannerWithDate.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne · données du {date}'**
  String offlineBannerWithDate(String date);

  /// No description provided for @notifChannelDebtsName.
  ///
  /// In fr, this message translates to:
  /// **'Dettes et remboursements'**
  String get notifChannelDebtsName;

  /// No description provided for @notifChannelDebtsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Dettes partagées, remboursements et rappels d\'échéance.'**
  String get notifChannelDebtsDesc;

  /// No description provided for @notifChannelScheduledExpensesName.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses programmées'**
  String get notifChannelScheduledExpensesName;

  /// No description provided for @notifChannelScheduledExpensesDesc.
  ///
  /// In fr, this message translates to:
  /// **'Rappels des dépenses que vous avez programmées.'**
  String get notifChannelScheduledExpensesDesc;

  /// No description provided for @notifChannelContactsName.
  ///
  /// In fr, this message translates to:
  /// **'Contacts'**
  String get notifChannelContactsName;

  /// No description provided for @notifChannelContactsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Alertes lorsqu\'un proche vous ajoute à ses contacts.'**
  String get notifChannelContactsDesc;

  /// No description provided for @notifChannelJointAccountsName.
  ///
  /// In fr, this message translates to:
  /// **'Comptes conjoints'**
  String get notifChannelJointAccountsName;

  /// No description provided for @notifChannelJointAccountsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Invitations et activité des comptes partagés.'**
  String get notifChannelJointAccountsDesc;

  /// No description provided for @notifChannelGeneralName.
  ///
  /// In fr, this message translates to:
  /// **'Général'**
  String get notifChannelGeneralName;

  /// No description provided for @notifChannelGeneralDesc.
  ///
  /// In fr, this message translates to:
  /// **'Notifications de service FIMUS.'**
  String get notifChannelGeneralDesc;

  /// No description provided for @notifChannelAnnouncementsName.
  ///
  /// In fr, this message translates to:
  /// **'Annonces'**
  String get notifChannelAnnouncementsName;

  /// No description provided for @notifChannelAnnouncementsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Nouveautés, conseils et offres FIMUS. Sans son.'**
  String get notifChannelAnnouncementsDesc;

  /// No description provided for @loadMore.
  ///
  /// In fr, this message translates to:
  /// **'Charger plus'**
  String get loadMore;

  /// No description provided for @notificationFilterContacts.
  ///
  /// In fr, this message translates to:
  /// **'Contacts'**
  String get notificationFilterContacts;

  /// No description provided for @notificationFilterScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Programmées'**
  String get notificationFilterScheduled;

  /// No description provided for @notificationSectionEarlier.
  ///
  /// In fr, this message translates to:
  /// **'Plus tôt'**
  String get notificationSectionEarlier;

  /// No description provided for @notificationUnreadBadge.
  ///
  /// In fr, this message translates to:
  /// **'Non lu'**
  String get notificationUnreadBadge;

  /// No description provided for @notificationReadBadge.
  ///
  /// In fr, this message translates to:
  /// **'Lu'**
  String get notificationReadBadge;

  /// No description provided for @notificationTimeJustNow.
  ///
  /// In fr, this message translates to:
  /// **'À l\'instant'**
  String get notificationTimeJustNow;

  /// No description provided for @notificationTimeMinutesAgo.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{il y a {count} min} other{il y a {count} min}}'**
  String notificationTimeMinutesAgo(int count);

  /// No description provided for @notificationTimeHoursAgo.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{il y a {count} h} other{il y a {count} h}}'**
  String notificationTimeHoursAgo(int count);

  /// No description provided for @notificationDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Notification supprimée'**
  String get notificationDeleted;

  /// No description provided for @undoAction.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get undoAction;

  /// No description provided for @clearSelectionTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la sélection'**
  String get clearSelectionTooltip;

  /// No description provided for @notificationsSelectedCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} sélectionnée} other{{count} sélectionnées}}'**
  String notificationsSelectedCount(int count);

  /// No description provided for @notificationsEmptyForFilter.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification dans cette catégorie.'**
  String get notificationsEmptyForFilter;

  /// No description provided for @notificationsShowAllFilters.
  ///
  /// In fr, this message translates to:
  /// **'Voir toutes les notifications'**
  String get notificationsShowAllFilters;

  /// Titre de la section qui permet de choisir entre thème clair, sombre ou système
  ///
  /// In fr, this message translates to:
  /// **'Mode d\'affichage'**
  String get displayMode;

  /// Sous-titre du sélecteur de mode d'affichage
  ///
  /// In fr, this message translates to:
  /// **'Choisissez l\'apparence de l\'application'**
  String get displayModeSubtitle;

  /// Mode d'affichage suivant le réglage de l'appareil
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeModeSystem;

  /// Mode d'affichage clair
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeModeLight;

  /// Mode d'affichage sombre
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeModeDark;

  /// Nom du canal Android fimus_alerts_v3 (alertes locales de budget, solde et synchronisation)
  ///
  /// In fr, this message translates to:
  /// **'Alertes de finances'**
  String get notifChannelAlertsName;

  /// No description provided for @notifChannelAlertsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Budget atteint, solde bas, données en attente d\'envoi'**
  String get notifChannelAlertsDesc;

  /// No description provided for @alertBudgetWarningTitle.
  ///
  /// In fr, this message translates to:
  /// **'Budget bientôt atteint'**
  String get alertBudgetWarningTitle;

  /// Corps de l'alerte de budget au palier 80 %
  ///
  /// In fr, this message translates to:
  /// **'{category} : {percent} % du budget consommé ({spent} / {budget} {currency}) ce mois-ci.'**
  String alertBudgetWarningBody(
    String category,
    int percent,
    String spent,
    String budget,
    String currency,
  );

  /// No description provided for @alertBudgetReachedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Budget dépassé'**
  String get alertBudgetReachedTitle;

  /// Corps de l'alerte de budget au palier 100 %
  ///
  /// In fr, this message translates to:
  /// **'{category} : {percent} % du budget consommé ({spent} / {budget} {currency}) ce mois-ci.'**
  String alertBudgetReachedBody(
    String category,
    int percent,
    String spent,
    String budget,
    String currency,
  );

  /// No description provided for @alertLowBalanceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Solde bas'**
  String get alertLowBalanceTitle;

  /// Corps de l'alerte de solde bas
  ///
  /// In fr, this message translates to:
  /// **'{account} : {balance} {currency}, sous votre seuil de {threshold} {currency}.'**
  String alertLowBalanceBody(
    String account,
    String balance,
    String threshold,
    String currency,
  );

  /// No description provided for @alertUnsyncedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Données non synchronisées'**
  String get alertUnsyncedTitle;

  /// Corps de l'alerte de données non synchronisées
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{1 opération en attente depuis {hours} h. Synchronisez pour ne rien perdre.} other{{count} opérations en attente depuis {hours} h. Synchronisez pour ne rien perdre.}}'**
  String alertUnsyncedBody(int count, int hours);

  /// No description provided for @localAlertsSection.
  ///
  /// In fr, this message translates to:
  /// **'Alertes personnalisées'**
  String get localAlertsSection;

  /// No description provided for @alertsLocalOnlyNotice.
  ///
  /// In fr, this message translates to:
  /// **'Ces réglages sont enregistrés sur cet appareil uniquement : ils ne suivent pas votre compte sur un autre téléphone.'**
  String get alertsLocalOnlyNotice;

  /// No description provided for @alertBudgetSwitchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Seuil de budget'**
  String get alertBudgetSwitchTitle;

  /// No description provided for @alertBudgetSwitchDesc.
  ///
  /// In fr, this message translates to:
  /// **'Vous prévenir à 80 % puis à 100 % du budget mensuel d\'une catégorie'**
  String get alertBudgetSwitchDesc;

  /// No description provided for @alertLowBalanceSwitchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Solde bas'**
  String get alertLowBalanceSwitchTitle;

  /// No description provided for @alertLowBalanceSwitchDesc.
  ///
  /// In fr, this message translates to:
  /// **'Vous prévenir quand un compte passe sous son seuil'**
  String get alertLowBalanceSwitchDesc;

  /// No description provided for @alertUnsyncedSwitchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Données non synchronisées'**
  String get alertUnsyncedSwitchTitle;

  /// No description provided for @alertUnsyncedSwitchDesc.
  ///
  /// In fr, this message translates to:
  /// **'Vous prévenir quand des opérations attendent trop longtemps d\'être envoyées'**
  String get alertUnsyncedSwitchDesc;

  /// No description provided for @alertBudgetsManageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Budgets mensuels par catégorie'**
  String get alertBudgetsManageTitle;

  /// No description provided for @alertThresholdsManageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Seuils de solde par compte'**
  String get alertThresholdsManageTitle;

  /// No description provided for @alertTrackedNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun suivi configuré'**
  String get alertTrackedNone;

  /// No description provided for @alertBudgetsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{1 catégorie suivie} other{{count} catégories suivies}}'**
  String alertBudgetsCount(int count);

  /// No description provided for @alertThresholdsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{1 compte suivi} other{{count} comptes suivis}}'**
  String alertThresholdsCount(int count);

  /// No description provided for @alertUnsyncedDelayTitle.
  ///
  /// In fr, this message translates to:
  /// **'Délai avant alerte'**
  String get alertUnsyncedDelayTitle;

  /// No description provided for @alertUnsyncedDelayValue.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, one{1 jour} other{{days} jours}}'**
  String alertUnsyncedDelayValue(int days);

  /// No description provided for @alertBudgetsDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Budgets mensuels'**
  String get alertBudgetsDialogTitle;

  /// No description provided for @alertThresholdsDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Seuils de solde bas'**
  String get alertThresholdsDialogTitle;

  /// No description provided for @alertBudgetFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Budget mensuel'**
  String get alertBudgetFieldLabel;

  /// No description provided for @alertThresholdFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Seuil d\'alerte'**
  String get alertThresholdFieldLabel;

  /// No description provided for @alertValueNotSet.
  ///
  /// In fr, this message translates to:
  /// **'Non défini'**
  String get alertValueNotSet;

  /// No description provided for @alertNoCategories.
  ///
  /// In fr, this message translates to:
  /// **'Aucune catégorie de dépense disponible.'**
  String get alertNoCategories;

  /// No description provided for @alertNoAccounts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte disponible.'**
  String get alertNoAccounts;

  /// No description provided for @alertInvalidAmount.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant valide.'**
  String get alertInvalidAmount;

  /// No description provided for @alertResetStateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser les alertes déjà envoyées'**
  String get alertResetStateTitle;

  /// No description provided for @alertResetStateDesc.
  ///
  /// In fr, this message translates to:
  /// **'Autorise à nouveau les alertes déjà reçues ce mois-ci'**
  String get alertResetStateDesc;

  /// No description provided for @alertResetStateDone.
  ///
  /// In fr, this message translates to:
  /// **'Alertes réinitialisées'**
  String get alertResetStateDone;

  /// No description provided for @savingInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement en cours...'**
  String get savingInProgress;

  /// No description provided for @savedLocallyWillSync.
  ///
  /// In fr, this message translates to:
  /// **'L\'opération a été enregistrée sur votre téléphone. Elle sera synchronisée dès le retour de la connexion internet.'**
  String get savedLocallyWillSync;

  /// No description provided for @genericErrorRetry.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur s\'est produite. Veuillez réessayer.'**
  String get genericErrorRetry;

  /// No description provided for @debtOpCollectRepaymentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Percevoir un remboursement'**
  String get debtOpCollectRepaymentTitle;

  /// No description provided for @debtOpRepayDebtTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rembourser une dette'**
  String get debtOpRepayDebtTitle;

  /// No description provided for @debtOpNewBorrowTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel emprunt (Dette)'**
  String get debtOpNewBorrowTitle;

  /// No description provided for @debtOpNewLoanTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau prêt (Créance)'**
  String get debtOpNewLoanTitle;

  /// No description provided for @debtOpCollectFromHint.
  ///
  /// In fr, this message translates to:
  /// **'Percevoir un remboursement de la part de {name}'**
  String debtOpCollectFromHint(String name);

  /// No description provided for @debtOpRepayToHint.
  ///
  /// In fr, this message translates to:
  /// **'Rembourser la dette envers {name}'**
  String debtOpRepayToHint(String name);

  /// No description provided for @debtOpSettledSuffix.
  ///
  /// In fr, this message translates to:
  /// **'(Soldé)'**
  String get debtOpSettledSuffix;

  /// No description provided for @debtOpTotalToRepay.
  ///
  /// In fr, this message translates to:
  /// **'Total à rembourser : {amount} {currency}'**
  String debtOpTotalToRepay(String amount, String currency);

  /// No description provided for @receivableInterestSimulator.
  ///
  /// In fr, this message translates to:
  /// **'Créance avec intérêt (Simulateur)'**
  String get receivableInterestSimulator;

  /// No description provided for @debtOpNoCashFlowImpact.
  ///
  /// In fr, this message translates to:
  /// **'Cette opération est purement indicative et n\'impactera ni vos comptes, ni vos statistiques.'**
  String get debtOpNoCashFlowImpact;

  /// No description provided for @debtOpNoLinkableAccount.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte disponible pour être lié.'**
  String get debtOpNoLinkableAccount;

  /// No description provided for @pleaseChooseAccount.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez choisir un compte'**
  String get pleaseChooseAccount;

  /// No description provided for @debtOpSetDueDate.
  ///
  /// In fr, this message translates to:
  /// **'Définir une date d\'échéance'**
  String get debtOpSetDueDate;

  /// No description provided for @debtOpSetDueDateDesc.
  ///
  /// In fr, this message translates to:
  /// **'Date limite de remboursement recommandée'**
  String get debtOpSetDueDateDesc;

  /// No description provided for @debtOpDueDatePlanned.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'échéance prévue'**
  String get debtOpDueDatePlanned;

  /// No description provided for @selectDate.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une date'**
  String get selectDate;

  /// No description provided for @frequencyMonthly.
  ///
  /// In fr, this message translates to:
  /// **'Mensuelle'**
  String get frequencyMonthly;

  /// No description provided for @frequencyWeekly.
  ///
  /// In fr, this message translates to:
  /// **'Hebdomadaire'**
  String get frequencyWeekly;

  /// No description provided for @frequencyDaily.
  ///
  /// In fr, this message translates to:
  /// **'Quotidienne'**
  String get frequencyDaily;

  /// No description provided for @frequencyAnnual.
  ///
  /// In fr, this message translates to:
  /// **'Annuelle'**
  String get frequencyAnnual;

  /// No description provided for @debtBadgeSettled.
  ///
  /// In fr, this message translates to:
  /// **'Soldé'**
  String get debtBadgeSettled;

  /// No description provided for @debtBadgeToRepay.
  ///
  /// In fr, this message translates to:
  /// **'Dette à rembourser'**
  String get debtBadgeToRepay;

  /// No description provided for @debtBadgeToCollect.
  ///
  /// In fr, this message translates to:
  /// **'Créance à encaisser'**
  String get debtBadgeToCollect;

  /// No description provided for @filterLabel.
  ///
  /// In fr, this message translates to:
  /// **'Filtre :'**
  String get filterLabel;

  /// No description provided for @validate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get validate;

  /// No description provided for @debtKind.
  ///
  /// In fr, this message translates to:
  /// **'Dette'**
  String get debtKind;

  /// No description provided for @receivableKind.
  ///
  /// In fr, this message translates to:
  /// **'Créance'**
  String get receivableKind;

  /// No description provided for @createdByMe.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get createdByMe;

  /// No description provided for @createdByMember.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get createdByMember;

  /// No description provided for @debtNewOperationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle opération de dette'**
  String get debtNewOperationTitle;

  /// No description provided for @debtSelectTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une dette'**
  String get debtSelectTitle;

  /// No description provided for @someone.
  ///
  /// In fr, this message translates to:
  /// **'Quelqu\'un'**
  String get someone;

  /// No description provided for @debtPendingInvitation.
  ///
  /// In fr, this message translates to:
  /// **'{name} vous a associé à une dette : {title}'**
  String debtPendingInvitation(String name, String title);

  /// No description provided for @debtDueDateOverdue.
  ///
  /// In fr, this message translates to:
  /// **'Échéance dépassée : {date}'**
  String debtDueDateOverdue(String date);

  /// No description provided for @debtDueDatePlanned.
  ///
  /// In fr, this message translates to:
  /// **'Échéance prévue : {date}'**
  String debtDueDatePlanned(String date);

  /// No description provided for @debtDueDateValue.
  ///
  /// In fr, this message translates to:
  /// **'Échéance : {date}'**
  String debtDueDateValue(String date);

  /// No description provided for @selectPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une période'**
  String get selectPeriod;

  /// No description provided for @selectPeriodMax6Months.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une période (max 6 mois)'**
  String get selectPeriodMax6Months;

  /// No description provided for @operationsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} opération} other{{count} opérations}}'**
  String operationsCount(int count);

  /// No description provided for @exampleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Exemple :'**
  String get exampleLabel;

  /// No description provided for @ussdQuickInsertChips.
  ///
  /// In fr, this message translates to:
  /// **'Puces d\'insertion rapide :'**
  String get ussdQuickInsertChips;

  /// No description provided for @ussdPreviewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu de l\'écran d\'exécution'**
  String get ussdPreviewTitle;

  /// No description provided for @ussdPreviewEmptyHint.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un code USSD contenant des variables comme {first} ou {second} pour générer l\'aperçu.'**
  String ussdPreviewEmptyHint(String first, String second);

  /// No description provided for @ussdAmountToTransferLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montant à transférer'**
  String get ussdAmountToTransferLabel;

  /// No description provided for @productPhotoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Photo du produit'**
  String get productPhotoTitle;

  /// No description provided for @takePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get chooseFromGallery;

  /// No description provided for @deletePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo'**
  String get deletePhoto;

  /// No description provided for @addPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter photo'**
  String get addPhoto;

  /// No description provided for @productUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Produit mis à jour'**
  String get productUpdated;

  /// No description provided for @productSaved.
  ///
  /// In fr, this message translates to:
  /// **'Produit enregistré avec succès'**
  String get productSaved;

  /// No description provided for @editProductTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le produit'**
  String get editProductTitle;

  /// No description provided for @newProductTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau produit'**
  String get newProductTitle;

  /// No description provided for @productNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom du produit *'**
  String get productNameLabel;

  /// No description provided for @productNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Sac de riz 25 kg, Téléphone…'**
  String get productNameHint;

  /// No description provided for @productNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer le nom du produit'**
  String get productNameRequired;

  /// No description provided for @productPriceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prix de vente ({currency}) *'**
  String productPriceLabel(String currency);

  /// No description provided for @productPriceRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer le prix'**
  String get productPriceRequired;

  /// No description provided for @productPriceInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Prix invalide'**
  String get productPriceInvalid;

  /// No description provided for @productDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnelle)'**
  String get productDescriptionLabel;

  /// No description provided for @productDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Détails, taille, couleur, conditionnement…'**
  String get productDescriptionHint;

  /// No description provided for @updateAction.
  ///
  /// In fr, this message translates to:
  /// **'METTRE À JOUR'**
  String get updateAction;

  /// No description provided for @saveProductAction.
  ///
  /// In fr, this message translates to:
  /// **'ENREGISTRER LE PRODUIT'**
  String get saveProductAction;

  /// No description provided for @staffUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Membre mis à jour'**
  String get staffUpdated;

  /// No description provided for @staffAdded.
  ///
  /// In fr, this message translates to:
  /// **'Collaborateur ajouté avec succès'**
  String get staffAdded;

  /// No description provided for @editStaffTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le collaborateur'**
  String get editStaffTitle;

  /// No description provided for @newStaffTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau collaborateur'**
  String get newStaffTitle;

  /// No description provided for @staffNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom & Prénom *'**
  String get staffNameLabel;

  /// No description provided for @staffNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Amadou Diallo'**
  String get staffNameHint;

  /// No description provided for @staffNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer le nom'**
  String get staffNameRequired;

  /// No description provided for @staffRoleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rôle / Poste'**
  String get staffRoleLabel;

  /// No description provided for @staffRoleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Comptable, Commercial, Technicien…'**
  String get staffRoleHint;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone'**
  String get phoneNumberLabel;

  /// No description provided for @staffPhoneHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : +221 77 123 45 67'**
  String get staffPhoneHint;

  /// No description provided for @emailAddressLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse Email'**
  String get emailAddressLabel;

  /// No description provided for @staffEmailHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : amadou@entreprise.com'**
  String get staffEmailHint;

  /// No description provided for @staffSalaryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rémunération mensuelle ({currency})'**
  String staffSalaryLabel(String currency);

  /// No description provided for @addStaffAction.
  ///
  /// In fr, this message translates to:
  /// **'AJOUTER LE COLLABORATEUR'**
  String get addStaffAction;

  /// No description provided for @deleteProductTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce produit ?'**
  String get deleteProductTitle;

  /// No description provided for @deleteProductConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer « {name} » ?'**
  String deleteProductConfirm(String name);

  /// No description provided for @productDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Produit « {name} » supprimé'**
  String productDeleted(String name);

  /// No description provided for @searchProductHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un produit…'**
  String get searchProductHint;

  /// No description provided for @productsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} produit} other{{count} produits}}'**
  String productsCount(int count);

  /// No description provided for @noProductFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit trouvé'**
  String get noProductFound;

  /// No description provided for @emptyCatalog.
  ///
  /// In fr, this message translates to:
  /// **'Votre catalogue est vide'**
  String get emptyCatalog;

  /// No description provided for @trySearchAgain.
  ///
  /// In fr, this message translates to:
  /// **'Essayez une autre recherche.'**
  String get trySearchAgain;

  /// No description provided for @emptyCatalogHint.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez vos articles pour gérer vos ventes rapidement.'**
  String get emptyCatalogHint;

  /// No description provided for @addFirstProduct.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter mon premier produit'**
  String get addFirstProduct;

  /// No description provided for @deleteStaffTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce collaborateur ?'**
  String get deleteStaffTitle;

  /// No description provided for @deleteStaffConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment retirer « {name} » de votre équipe ?'**
  String deleteStaffConfirm(String name);

  /// No description provided for @staffDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Collaborateur « {name} » supprimé'**
  String staffDeleted(String name);

  /// No description provided for @searchStaffHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un membre de l\'équipe…'**
  String get searchStaffHint;

  /// No description provided for @staffCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} collaborateur} other{{count} collaborateurs}}'**
  String staffCount(int count);

  /// No description provided for @noStaffFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun collaborateur trouvé'**
  String get noStaffFound;

  /// No description provided for @noStaffRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Aucun collaborateur enregistré'**
  String get noStaffRecorded;

  /// No description provided for @emptyStaffHint.
  ///
  /// In fr, this message translates to:
  /// **'Organisez votre équipe, les rôles et contacts professionnels.'**
  String get emptyStaffHint;

  /// No description provided for @addStaffMember.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un collaborateur'**
  String get addStaffMember;

  /// No description provided for @googleSignInInterrupted.
  ///
  /// In fr, this message translates to:
  /// **'Connexion interrompue, réessayez.'**
  String get googleSignInInterrupted;

  /// No description provided for @googleSignInNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte Google trouvé. Ajoutez-en un ou utilisez email/mot de passe.'**
  String get googleSignInNoAccount;

  /// No description provided for @googleSignInUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Configuration indisponible. Veuillez réessayer plus tard.'**
  String get googleSignInUnavailable;

  /// No description provided for @googleSignInUpdatePlayServices.
  ///
  /// In fr, this message translates to:
  /// **'Mettez à jour Google Play Services.'**
  String get googleSignInUpdatePlayServices;

  /// No description provided for @googleSignInAccountChanged.
  ///
  /// In fr, this message translates to:
  /// **'Changement de compte détecté, réessayez.'**
  String get googleSignInAccountChanged;

  /// No description provided for @googleSignInGenericError.
  ///
  /// In fr, this message translates to:
  /// **'La connexion Google a échoué. Veuillez réessayer.'**
  String get googleSignInGenericError;

  /// No description provided for @forgotPasswordSent.
  ///
  /// In fr, this message translates to:
  /// **'Un nouveau mot de passe a été envoyé à votre adresse email. Veuillez vérifier vos spams si le message n\'est pas dans la boîte principale.'**
  String get forgotPasswordSent;

  /// No description provided for @loginSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour gérer vos finances'**
  String get loginSubtitle;

  /// No description provided for @loginAction.
  ///
  /// In fr, this message translates to:
  /// **'SE CONNECTER'**
  String get loginAction;

  /// No description provided for @orSeparator.
  ///
  /// In fr, this message translates to:
  /// **'OU'**
  String get orSeparator;

  /// No description provided for @noAccountQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas de compte ? '**
  String get noAccountQuestion;

  /// No description provided for @haveAccountQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà un compte ? '**
  String get haveAccountQuestion;

  /// No description provided for @registerAccountAction.
  ///
  /// In fr, this message translates to:
  /// **'CRÉER MON COMPTE'**
  String get registerAccountAction;

  /// No description provided for @registerSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Créez votre compte en quelques secondes'**
  String get registerSubtitle;

  /// No description provided for @registerSuccessEmailSent.
  ///
  /// In fr, this message translates to:
  /// **'Compte créé ! Votre mot de passe vous a été envoyé par email afin de ne pas l\'oublier.'**
  String get registerSuccessEmailSent;

  /// No description provided for @startAction.
  ///
  /// In fr, this message translates to:
  /// **'DÉMARRER'**
  String get startAction;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @onboardingStepProgress.
  ///
  /// In fr, this message translates to:
  /// **'Étape {current} sur {total}'**
  String onboardingStepProgress(int current, int total);

  /// No description provided for @onboardingCountryHint.
  ///
  /// In fr, this message translates to:
  /// **'FIMUS adapte vos opérateurs et codes USSD en fonction de votre localisation.'**
  String get onboardingCountryHint;

  /// No description provided for @onboardingProfileTypeHint.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre type d\'utilisation pour adapter l\'interface.'**
  String get onboardingProfileTypeHint;

  /// No description provided for @profileTypePersonal.
  ///
  /// In fr, this message translates to:
  /// **'Personnel'**
  String get profileTypePersonal;

  /// No description provided for @profileTypeSmallBusiness.
  ///
  /// In fr, this message translates to:
  /// **'Petit commerce'**
  String get profileTypeSmallBusiness;

  /// No description provided for @profileTypeSmallBusinessShort.
  ///
  /// In fr, this message translates to:
  /// **'Commerce'**
  String get profileTypeSmallBusinessShort;

  /// No description provided for @profileTypeSmallBusinessDesc.
  ///
  /// In fr, this message translates to:
  /// **'Vente & Produits'**
  String get profileTypeSmallBusinessDesc;

  /// No description provided for @profileTypeCompany.
  ///
  /// In fr, this message translates to:
  /// **'Entreprise'**
  String get profileTypeCompany;

  /// No description provided for @profileTypeCompanyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Services & Équipe'**
  String get profileTypeCompanyDesc;

  /// No description provided for @profileTypeKiosk.
  ///
  /// In fr, this message translates to:
  /// **'Kiosque'**
  String get profileTypeKiosk;

  /// No description provided for @profileTypeKioskDesc.
  ///
  /// In fr, this message translates to:
  /// **'Transfert d\'argent'**
  String get profileTypeKioskDesc;

  /// No description provided for @lockTooManyAttemptsReauth.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Reconnectez-vous avec votre mot de passe.'**
  String get lockTooManyAttemptsReauth;

  /// No description provided for @lockTooManyAttemptsRetryIn.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessayez dans {delay}.'**
  String lockTooManyAttemptsRetryIn(String delay);

  /// No description provided for @verifying.
  ///
  /// In fr, this message translates to:
  /// **'Vérification…'**
  String get verifying;

  /// No description provided for @lockIncorrectPinAttemptsLeft.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{Code PIN incorrect · {count} essai avant blocage} other{Code PIN incorrect · {count} essais avant blocage}}'**
  String lockIncorrectPinAttemptsLeft(int count);

  /// No description provided for @enterYourPin.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre code PIN'**
  String get enterYourPin;

  /// No description provided for @securityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get securityTitle;

  /// No description provided for @lockFullReauthBody.
  ///
  /// In fr, this message translates to:
  /// **'Trop de codes PIN erronés ont été saisis. Pour votre sécurité, reconnectez-vous avec votre mot de passe. Vos données locales sont conservées.'**
  String get lockFullReauthBody;

  /// No description provided for @reconnectAction.
  ///
  /// In fr, this message translates to:
  /// **'Se reconnecter'**
  String get reconnectAction;

  /// No description provided for @lockForgotPinBody.
  ///
  /// In fr, this message translates to:
  /// **'Pour des raisons de sécurité, si vous avez oublié votre code PIN, vous devez vous déconnecter et vous reconnecter. Vos données locales synchronisées seront préservées.'**
  String get lockForgotPinBody;

  /// No description provided for @ussdLoadingCodes.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des codes USSD…'**
  String get ussdLoadingCodes;

  /// No description provided for @ussdNoOperatorAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucun opérateur disponible'**
  String get ussdNoOperatorAvailable;

  /// No description provided for @ussdSelectCountryOrAddOperator.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un pays ou ajoutez un opérateur'**
  String get ussdSelectCountryOrAddOperator;

  /// No description provided for @ussdAddOperatorSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Configurez un nouvel opérateur télécom pour vos codes USSD'**
  String get ussdAddOperatorSubtitle;

  /// No description provided for @ussdHiddenBadge.
  ///
  /// In fr, this message translates to:
  /// **'Masqué'**
  String get ussdHiddenBadge;

  /// No description provided for @ussdHideOperation.
  ///
  /// In fr, this message translates to:
  /// **'Masquer l\'opération'**
  String get ussdHideOperation;

  /// No description provided for @ussdShowOperation.
  ///
  /// In fr, this message translates to:
  /// **'Afficher l\'opération'**
  String get ussdShowOperation;

  /// No description provided for @navProducts.
  ///
  /// In fr, this message translates to:
  /// **'Produits'**
  String get navProducts;

  /// No description provided for @navStaff.
  ///
  /// In fr, this message translates to:
  /// **'Équipe'**
  String get navStaff;

  /// No description provided for @changeProfileAction.
  ///
  /// In fr, this message translates to:
  /// **'Changer de profil'**
  String get changeProfileAction;

  /// No description provided for @profileTypeChooseNew.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un nouveau profil'**
  String get profileTypeChooseNew;

  /// No description provided for @profileTypeChangeWarningOnce.
  ///
  /// In fr, this message translates to:
  /// **'Attention : ce changement est unique et définitif.'**
  String get profileTypeChangeWarningOnce;

  /// No description provided for @profileChangeToSmallBusinessDesc.
  ///
  /// In fr, this message translates to:
  /// **'En passant au profil Petit commerce, vous aurez accès au catalogue de produits pour enregistrer et suivre vos articles en vente.'**
  String get profileChangeToSmallBusinessDesc;

  /// No description provided for @profileChangeToCompanyDesc.
  ///
  /// In fr, this message translates to:
  /// **'En passant au profil Entreprise, vous aurez accès au module Staff pour gérer vos collaborateurs, postes et contacts d\'équipe.'**
  String get profileChangeToCompanyDesc;

  /// No description provided for @profileChangeToKioskDesc.
  ///
  /// In fr, this message translates to:
  /// **'En passant au profil Kiosque, vous aurez accès aux codes USSD Marchand / Agent et aux outils de tenue de caisse Mobile Money.'**
  String get profileChangeToKioskDesc;

  /// No description provided for @announcementFallback1.
  ///
  /// In fr, this message translates to:
  /// **'Configurez vos codes USSD préférés pour exécuter vos transactions en un seul clic !'**
  String get announcementFallback1;

  /// No description provided for @announcementFallback2.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez désormais ajouter ou supprimer vos opérateurs USSD personnalisés en toute simplicité.'**
  String get announcementFallback2;

  /// No description provided for @announcementFallback3.
  ///
  /// In fr, this message translates to:
  /// **'Suivi de budget : Suivez vos dépenses quotidiennes et maîtrisez votre budget grâce à nos rapports détaillés.'**
  String get announcementFallback3;

  /// No description provided for @notifyWeeklyDigestPref.
  ///
  /// In fr, this message translates to:
  /// **'Bilan hebdomadaire'**
  String get notifyWeeklyDigestPref;

  /// No description provided for @notifyWeeklyDigestPrefDesc.
  ///
  /// In fr, this message translates to:
  /// **'Résumé de vos dépenses de la semaine, envoyé chaque dimanche.'**
  String get notifyWeeklyDigestPrefDesc;

  /// No description provided for @newLoginConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce n\'était pas vous ?'**
  String get newLoginConfirmTitle;

  /// No description provided for @newLoginConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les autres sessions de votre compte seront déconnectées. Cet appareil restera connecté.'**
  String get newLoginConfirmBody;

  /// No description provided for @newLoginConfirmBodyWithDetails.
  ///
  /// In fr, this message translates to:
  /// **'Connexion détectée : {details}.\n\nToutes les autres sessions de votre compte seront déconnectées. Cet appareil restera connecté.'**
  String newLoginConfirmBodyWithDetails(String details);

  /// No description provided for @newLoginConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Ce n\'était pas moi'**
  String get newLoginConfirmAction;

  /// No description provided for @revokeOtherSessionsDone.
  ///
  /// In fr, this message translates to:
  /// **'{sessions} session(s) et {devices} appareil(s) déconnectés. Changez votre mot de passe si vous ne reconnaissez pas cette connexion.'**
  String revokeOtherSessionsDone(int sessions, int devices);

  /// No description provided for @revokeOtherSessionsError.
  ///
  /// In fr, this message translates to:
  /// **'La révocation a échoué. Vérifiez votre connexion, puis réessayez depuis les réglages de sécurité.'**
  String get revokeOtherSessionsError;
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
