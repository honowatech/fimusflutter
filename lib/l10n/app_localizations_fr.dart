// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'FIMUS';

  @override
  String get settings => 'Paramètres';

  @override
  String get preferences => 'Préférences';

  @override
  String get operators => 'Opérateurs';

  @override
  String get ussdCodes => 'Codes USSD';

  @override
  String get ussdCategories => 'Catégories USSD';

  @override
  String get expenseCategories => 'Catégories Dépenses';

  @override
  String get appLanguage => 'Langue de l\'application';

  @override
  String get currency => 'Devise';

  @override
  String get french => 'Français';

  @override
  String get english => 'English';

  @override
  String get addOperator => 'Ajouter un opérateur';

  @override
  String get addUssdCodeFor => 'Ajouter un code USSD pour :';

  @override
  String get noOperatorAvailable =>
      'Aucun opérateur disponible. Ajoutez-en un d\'abord.';

  @override
  String get addExpenseCategory => 'Ajouter une catégorie de dépense';

  @override
  String get addUssdCategory => 'Ajouter une catégorie USSD';

  @override
  String get categoryName => 'Nom de la catégorie';

  @override
  String get addNew => 'Créer Nouvelle';

  @override
  String get cancel => 'Annuler';

  @override
  String get add => 'Ajouter';

  @override
  String get editOperator => 'Modifier l\'opérateur';

  @override
  String get country => 'Pays';

  @override
  String get allCountries => 'Tous les pays';

  @override
  String get sortByCountry => 'Trier par pays';

  @override
  String get operatorName => 'Nom de l\'opérateur';

  @override
  String get yourPhoneNumber => 'Votre numéro de téléphone';

  @override
  String get save => 'Enregistrer';

  @override
  String get deleteOperator => 'Supprimer l\'opérateur';

  @override
  String deleteOperatorConfirm(String name) {
    return 'Êtes-vous sûr de vouloir supprimer l\'opérateur $name ? Toutes les opérations USSD associées seront également supprimées.';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String myNumber(String number) {
    return 'Mon numéro: $number';
  }

  @override
  String get noNumberDefined => 'Aucun numéro défini';

  @override
  String availableVariables(String variables) {
    return 'Variables disponibles: $variables';
  }

  @override
  String get ussdTemplate => 'Modèle de code USSD';

  @override
  String get codeUpdatedSuccess => 'Code mis à jour avec succès';

  @override
  String get resetToDefault => 'Réinitialiser';

  @override
  String get codeResetSuccess => 'Code réinitialisé par défaut';

  @override
  String get cannotDeleteOther =>
      'La catégorie \'Autre\' ne peut pas être supprimée';

  @override
  String get expenses => 'Dépenses';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get history => 'Historique';

  @override
  String get accounts => 'Comptes';

  @override
  String get newOperation => 'Nouvelle opération';

  @override
  String get ussdMenu => 'USSD';

  @override
  String get expense => 'Dépense';

  @override
  String get income => 'Revenu';

  @override
  String get monthOverview => 'Aperçu du mois';

  @override
  String get incomes => 'Revenus';

  @override
  String get yourAccounts => 'Vos Comptes';

  @override
  String get totalBalance => 'Solde Total';

  @override
  String get noAccountSaved => 'Aucun compte enregistré.';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get thisMonth => 'Ce mois';

  @override
  String get all => 'Toutes';

  @override
  String get noOperationPeriod => 'Aucune opération pour cette période.';

  @override
  String get addAccount => 'Ajouter un compte';

  @override
  String get editAccount => 'Modifier le compte';

  @override
  String get accountName => 'Nom du compte (ex: Espèces, Banque)';

  @override
  String get initialBalance => 'Solde initial';

  @override
  String get deleteAccountConfirm => 'Supprimer ce compte ?';

  @override
  String get irreversibleAction => 'Cette action est irréversible.';

  @override
  String get addIncome => 'Ajouter un revenu';

  @override
  String get addExpense => 'Ajouter une dépense';

  @override
  String get title => 'Titre';

  @override
  String get required => 'Requis';

  @override
  String get amount => 'Montant';

  @override
  String get invalidNumber => 'Nombre invalide';

  @override
  String get category => 'Catégorie';

  @override
  String get pleaseChooseCategory => 'Veuillez choisir une catégorie';

  @override
  String get linkedAccountOptional => 'Compte associé (Optionnel)';

  @override
  String get noAccount => 'Aucun compte';

  @override
  String get date => 'Date';

  @override
  String get saveIncome => 'Enregistrer le revenu';

  @override
  String get saveExpense => 'Enregistrer la dépense';

  @override
  String get finishReorder => 'Terminer la réorganisation';

  @override
  String get reorderOperations => 'Réorganiser les opérations';

  @override
  String get noOperationForOperator => 'Aucune opération pour cet opérateur.';

  @override
  String get editOperation => 'Modifier l\'opération';

  @override
  String get operationName => 'Nom de l\'opération';

  @override
  String get ussdCodeExample => 'Code USSD (ex: *126#)';

  @override
  String get recipientNumber => 'Numéro du destinataire';

  @override
  String amountToTransfer(String currency) {
    return 'Montant à transférer ($currency)';
  }

  @override
  String get merchantCode => 'Code marchand';

  @override
  String limitPerOperation(String currency) {
    return 'Plafond : 500 000 $currency par opération';
  }

  @override
  String feeFlat3333(String currency) {
    return '54 $currency forfaitaires';
  }

  @override
  String feePercent266666(String currency) {
    return '1,5 % + 4 $currency (droit fixe)';
  }

  @override
  String feeFlatMax(String currency) {
    return '4 004 $currency forfaitaires';
  }

  @override
  String get enterAmountToSeeFees =>
      'Saisissez un montant pour voir le détail des frais';

  @override
  String get feesBreakdown => 'Détail des frais';

  @override
  String get amountToSend => 'Montant à envoyer';

  @override
  String withdrawalFees(String label) {
    return 'Frais de retrait ($label)';
  }

  @override
  String get ttaTax => 'TTA (0,2 % — loi finances 2022)';

  @override
  String get totalFees => 'Total frais';

  @override
  String get amountDebited => 'Montant débité';

  @override
  String operatorLabel(String name) {
    return 'Opérateur : $name';
  }

  @override
  String get fieldRequired => 'Ce champ est requis';

  @override
  String get pleaseEnterValidAmount => 'Veuillez saisir un montant valide';

  @override
  String regulatoryLimitExceeded(String currency) {
    return 'Le plafond réglementaire est de 500 000 $currency par opération';
  }

  @override
  String get includeWithdrawalFees => 'Inclure les frais de retrait';

  @override
  String get buyForAnother => 'Acheter pour un autre';

  @override
  String get executeOperation => 'Exécuter l\'opération';

  @override
  String get allLabel => 'Tous';

  @override
  String get noHistory => 'Aucun historique.';

  @override
  String noHistoryForOperator(String operator) {
    return 'Aucun historique pour $operator.';
  }

  @override
  String get sortBy => 'Trier par';

  @override
  String get sortByDate => 'Trier par date';

  @override
  String get sortByOperator => 'Trier par opérateur';

  @override
  String get clearHistoryConfirm => 'Effacer l\'historique ?';

  @override
  String get clearLabel => 'Effacer';

  @override
  String get deleteEntryConfirm => 'Supprimer l\'entrée ?';

  @override
  String get deleteEntryWarning =>
      'Voulez-vous vraiment supprimer cette ligne de l\'historique ?';

  @override
  String historyDate(String date) {
    return 'Date : $date';
  }

  @override
  String historyCode(String code) {
    return 'Code : $code';
  }

  @override
  String get profile => 'Profil';

  @override
  String get editProfileInfo => 'Modifier les informations';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get myOperators => 'Mes Opérateurs';

  @override
  String get statistics => 'Statistiques';

  @override
  String get configuredOperations => 'Opérations configurées';

  @override
  String get scanMerchantCode => 'Scanner le code marchand';

  @override
  String get placeQrCodeInFrame => 'Placez le QR code dans le cadre';

  @override
  String get optionalLabel => 'Optionnel';

  @override
  String get variablesLabel =>
      'Variables (séparées par des virgules, ex: contact, amount)';

  @override
  String get recentOperations => 'Actions récentes';

  @override
  String get incomeCategories => 'Catégories Revenus';

  @override
  String get addIncomeCategory => 'Ajouter une catégorie de revenu';

  @override
  String get debtsAndReceivables => 'Dettes';

  @override
  String get debts => 'Dettes';

  @override
  String get receivables => 'Créances';

  @override
  String get totalDebts => 'Total Dettes';

  @override
  String get totalReceivables => 'Total Créances';

  @override
  String get debtTag => 'Contact / Titulaire';

  @override
  String get addDebtTag => '+ Nouveau contact';

  @override
  String get debtBalance => 'Solde';

  @override
  String get recentDebtOperations => 'Dernières opérations';

  @override
  String get noDebtTags => 'Aucun contact défini';

  @override
  String get deleteDebtConfirm =>
      'Supprimer ce contact et toutes ses opérations ?';

  @override
  String get linkToCashFlow => 'Lier au flux de trésorerie ?';

  @override
  String get linkToCashFlowDescription =>
      'Si non, cette opération sera un simple mémo.';

  @override
  String get addDebtOperation => 'Ajouter une dette';

  @override
  String get confirm => 'Confirmer';

  @override
  String get filterActiveDebts => 'Actifs';

  @override
  String get filterOnlyDebts => 'Dettes';

  @override
  String get filterOnlyReceivables => 'Créances';

  @override
  String get filterSettled => 'Soldés';

  @override
  String get themeColor => 'Couleur du thème';

  @override
  String get saveAsExpense => 'Enregistrer comme dépense';

  @override
  String get onboardingWelcome => 'Bienvenue sur FIMUS';

  @override
  String get onboardingStep1 => 'Choisissez votre langue';

  @override
  String get onboardingStep2 => 'Sélectionnez votre pays';

  @override
  String get onboardingContinue => 'Continuer';

  @override
  String get onboardingFinish => 'Commencer';
}
