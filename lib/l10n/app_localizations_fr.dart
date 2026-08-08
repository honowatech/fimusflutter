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
  String get deleteOperation => 'Supprimer l\'opération';

  @override
  String deleteOperationConfirm(String name) {
    return 'Êtes-vous sûr de vouloir supprimer l\'opération $name ?';
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
  String get dashboard => 'Tableau de bord';

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
  String get debtsAndReceivables => 'Dettes & Créances';

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
  String get addDebtTag => 'Nouveau contact';

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
  String get linkToCashFlow => 'Lier à un compte';

  @override
  String get linkToCashFlowDescription =>
      'Impacte le solde du compte (encaissement ou sortie d\'argent).';

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
  String get onboardingStep3 => 'Choisissez votre profil';

  @override
  String get onboardingStep4 => 'Activer les notifications';

  @override
  String get onboardingNotificationExplanation =>
      'Si vous partagez un compte de dépenses ou une dette avec un proche, les notifications vous seront très utiles';

  @override
  String get onboardingEnableNotifications => 'Autoriser les notifications';

  @override
  String get onboardingNotificationsEnabled => 'Notifications autorisées';

  @override
  String get onboardingSkip => 'Plus tard';

  @override
  String get onboardingContinue => 'Continuer';

  @override
  String get onboardingFinish => 'Commencer';

  @override
  String get onboardingNotifHeader => 'Restez informé en temps réel';

  @override
  String get onboardingNotifSub =>
      'Ne manquez aucun remboursement, suivi de compte ou alerte importante.';

  @override
  String get onboardingNotifBenefit1Title => 'Rappels de dettes & échéances';

  @override
  String get onboardingNotifBenefit1Desc =>
      'Recevez un rappel automatique avant la date limite de remboursement.';

  @override
  String get onboardingNotifBenefit2Title => 'Activité des comptes partagés';

  @override
  String get onboardingNotifBenefit2Desc =>
      'Soyez averti dès qu\'un proche ajoute ou modifie une dépense.';

  @override
  String get onboardingNotifBenefit3Title => 'Sécurité & confirmation USSD';

  @override
  String get onboardingNotifBenefit3Desc =>
      'Gardez un contrôle total sur la validation de vos transactions.';

  @override
  String get home => 'Accueil';

  @override
  String get addIncomeAction => '+ Revenu';

  @override
  String get addBorrowAction => '+ Emprunt';

  @override
  String get addAccountAction => '+ Compte';

  @override
  String get addExpenseAction => '+ Dépense';

  @override
  String get addLendAction => '+ Prêt';

  @override
  String get myContacts => 'Mes contacts';

  @override
  String get noContactSaved => 'Aucun contact enregistré';

  @override
  String get addContactsExplanation =>
      'Ajoutez des contacts pour partager des comptes et gérer des dettes en commun.';

  @override
  String pseudoTag(String code) {
    return 'Pseudo : $code';
  }

  @override
  String get deleteContact => 'Supprimer le contact';

  @override
  String deleteContactConfirm(String name) {
    return 'Êtes-vous sûr de vouloir supprimer $name de vos contacts ?';
  }

  @override
  String contactHasActiveDebts(String contact) {
    return 'Vous avez des dettes en cours avec ce $contact';
  }

  @override
  String createdBy(String name) {
    return 'Par $name';
  }

  @override
  String get contactDeleted => 'Contact supprimé';

  @override
  String get errorOccurred => 'Une erreur s\'est produite';

  @override
  String shareAccount(String name) {
    return 'Partager \"$name\"';
  }

  @override
  String accountMembers(String name) {
    return 'Membres de \"$name\"';
  }

  @override
  String get currentMembers => 'Membres actuels :';

  @override
  String get unknown => 'Inconnu';

  @override
  String get shareWithContact => 'Partager avec un contact :';

  @override
  String get noContactToShare =>
      'Vous n\'avez aucun contact. Ajoutez des contacts dans votre profil pour partager un compte.';

  @override
  String get sharingInProgress => 'Partage en cours...';

  @override
  String accountSharedSuccess(String name) {
    return 'Compte partagé avec $name !';
  }

  @override
  String get shareImpossible =>
      'Partage impossible. Vérifiez votre connexion internet.';

  @override
  String get close => 'Fermer';

  @override
  String get share => 'Partager';

  @override
  String get unknownAccount => 'Compte inconnu';

  @override
  String get accountNotFound => 'Compte introuvable';

  @override
  String get untitled => 'Sans nom';

  @override
  String get tooltipShareAccount => 'Partager le compte';

  @override
  String get tooltipEditAccount => 'Modifier le compte';

  @override
  String get tooltipDeleteAccount => 'Supprimer le compte';

  @override
  String get tooltipViewMembers => 'Voir les membres';

  @override
  String get accountBalance => 'Solde du compte';

  @override
  String get sharedAccountBadge => 'En commun';

  @override
  String sharedByBadge(String name) {
    return 'Partagé par $name';
  }

  @override
  String get noOperationOnAccount => 'Aucune opération sur ce compte';

  @override
  String get newContact => 'Nouveau contact';

  @override
  String installmentTitle(String current, String total) {
    return 'Échéance $current/$total';
  }

  @override
  String get debtRepayment => 'Remboursement de dette';

  @override
  String get collectReceivable => 'Encaisser une créance';

  @override
  String get newReceivable => 'Nouvelle créance';

  @override
  String get newDebt => 'Nouvelle dette';

  @override
  String get collectMoney => 'Encaisser (Entrée d\'argent)';

  @override
  String get repayMoney => 'Rembourser (Sortie d\'argent)';

  @override
  String get receivableToCollect => 'Créance (Vous devez percevoir)';

  @override
  String get debtToRepay => 'Dette (Vous devez rembourser)';

  @override
  String get interestDebtSimulator => 'Dette avec intérêt (Simulateur)';

  @override
  String get interestDebtSubtitle =>
      'Calculer et planifier les échéances de remboursement automatiquement';

  @override
  String get creditDetails => 'Détails du crédit';

  @override
  String get interestRate => 'Taux d\'intérêt';

  @override
  String get periodicity => 'Périodicité';

  @override
  String get annual => 'Annuel';

  @override
  String get monthly => 'Mensuel';

  @override
  String get weekly => 'Hebdomadaire';

  @override
  String get daily => 'Quotidien';

  @override
  String get duration => 'Durée';

  @override
  String get unit => 'Unité';

  @override
  String get months => 'Mois';

  @override
  String get years => 'Années';

  @override
  String get repaymentFrequency => 'Fréquence de remboursement';

  @override
  String get amountPerInstallment => 'Montant par échéance';

  @override
  String get concernedAccount => 'Compte concerné *';

  @override
  String get selectAccount => 'Sélectionner un compte';

  @override
  String get addComment => 'Ajouter un commentaire';

  @override
  String get commentOptional => 'Commentaire (optionnel)';

  @override
  String get variableAmount => 'Montant';

  @override
  String get variableNumber => 'Numéro';

  @override
  String get variableMerchantCode => 'Code Marchand';

  @override
  String get noTransaction => 'Aucune transaction';

  @override
  String get expectedDueDate => 'Échéance prévue';

  @override
  String get memo => 'Mémo';

  @override
  String createdByName(String name) {
    return 'Créé par $name';
  }

  @override
  String get borrowAction => 'Emprunt';

  @override
  String get borrowSubtitle => 'Enregistrer une dette que vous avez contractée';

  @override
  String get lendAction => 'Créance';

  @override
  String get lendSubtitle => 'L\'argent que vous percevrez';

  @override
  String get repaymentAction => 'Remboursement';

  @override
  String get noDebtOrReceivableRecorded =>
      'Aucune dette ou créance enregistrée pour le moment.';

  @override
  String get toRepay => 'À rembourser';

  @override
  String get totalToCollect => 'Total à percevoir';

  @override
  String get noRecentOperation => 'Aucune opération récente';

  @override
  String get rejectDebt => 'Refuser la dette';

  @override
  String get rejectDebtConfirm =>
      'Êtes-vous sûr de vouloir supprimer cette dette ? Cette action est irréversible et retirera votre nom de cette opération.';

  @override
  String get forgotPin => 'Code PIN oublié ?';

  @override
  String get forgotPinConfirm =>
      'Pour déverrouiller l\'application sans votre PIN, vous devez vous déconnecter. Toutes les données non synchronisées seront conservées localement.';

  @override
  String get logout => 'Se déconnecter';

  @override
  String get setPin => 'Définir un PIN';

  @override
  String get confirmPin => 'Confirmer le PIN';

  @override
  String get verifyPin => 'Vérification du PIN';

  @override
  String get useBiometrics => 'Utiliser l\'empreinte / Face ID';

  @override
  String get username => 'Pseudo';

  @override
  String get pleaseEnterUsername => 'Veuillez entrer un pseudo';

  @override
  String get pleaseFillAllFields => 'Veuillez remplir tous les champs';

  @override
  String get pleaseEnterValidEmail => 'Veuillez entrer un email valide';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get forgotPasswordInstruction =>
      'Entrez votre adresse email pour recevoir un nouveau mot de passe.';

  @override
  String get email => 'Email';

  @override
  String get emailOrUsername => 'Email ou pseudo';

  @override
  String get password => 'Mot de passe';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get noNotifications => 'Aucune notification.';

  @override
  String get notifications => 'Notifications';

  @override
  String get officialLanguage => 'Langue officielle';

  @override
  String get defaultLanguage => 'Langue par défaut';

  @override
  String get individualProfile => 'Particulier';

  @override
  String get personalManagement => 'Gestion personnelle';

  @override
  String get mobileAgentProfile => 'Agent Mobile';

  @override
  String get kioskFleetProfile => 'Kiosque & Flotte';

  @override
  String get editUsername => 'Modifier l\'identifiant';

  @override
  String get editUsernameNotice =>
      'Votre identifiant doit être unique. S\'il est modifié avec succès, vos contacts seront notifiés.';

  @override
  String get newUsername => 'Nouvel identifiant (Pseudo)';

  @override
  String get usernameUpdatedSuccess => 'Identifiant modifié avec succès !';

  @override
  String get newPinCode => 'Nouveau code PIN';

  @override
  String get confirmPinCode => 'Confirmer le code PIN';

  @override
  String get pinLockActivated => 'Verrouillage activé avec succès';

  @override
  String get activate => 'Activer';

  @override
  String get currentPinCode => 'Code PIN actuel';

  @override
  String get pinLockDisabled => 'Verrouillage désactivé';

  @override
  String get incorrectPinCode => 'Code PIN incorrect';

  @override
  String get disable => 'Désactiver';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get login => 'Se connecter';

  @override
  String get addAccountTitle => 'Ajouter un compte';

  @override
  String get accountNameLabel => 'Nom du compte';

  @override
  String get accountColor => 'Couleur du compte';

  @override
  String get pleaseEnterName => 'Veuillez saisir un nom';

  @override
  String get addContactTitle => 'Ajouter un contact';

  @override
  String get userCodeLabel => 'Code utilisateur (ex: USR-12345)';

  @override
  String get search => 'Chercher';

  @override
  String get addToContacts => 'Ajouter aux contacts';

  @override
  String get contactNotFound => 'Contact introuvable';

  @override
  String get searchCountryHint => 'Rechercher un pays...';

  @override
  String get noCountryFound => 'Aucun pays trouvé';

  @override
  String get catExpenseFood => 'Alimentation';

  @override
  String get catExpenseTransport => 'Transport';

  @override
  String get catExpenseLeisure => 'Loisirs';

  @override
  String get catExpenseHealth => 'Santé';

  @override
  String get catExpenseBills => 'Factures';

  @override
  String get catExpenseOther => 'Autre';

  @override
  String get catIncomeSalary => 'Salaires';

  @override
  String get catIncomePension => 'Pension retraite';

  @override
  String get catIncomeFees => 'Honoraires';

  @override
  String get catIncomeProfits => 'Bénéfices';

  @override
  String get catIncomeDividends => 'Dividendes';

  @override
  String get catIncomeSale => 'Vente de bien';

  @override
  String get catIncomeDonations => 'Dons';

  @override
  String get catIncomeInheritance => 'Héritages';

  @override
  String get catIncomeOther => 'Autre';

  @override
  String get catUssdDeposit => 'Dépôt';

  @override
  String get catUssdWithdrawal => 'Retrait';

  @override
  String get catUssdTransfer => 'Transfert';

  @override
  String get catUssdMerchantPayment => 'Paiement marchand';

  @override
  String get catUssdCredit => 'Crédit';

  @override
  String get catUssdBalance => 'Solde';

  @override
  String get catUssdInternet => 'Internet';

  @override
  String get catUssdOther => 'Autre';

  @override
  String get ussdActionCashIn => 'Dépôt d\'argent (Cash-In)';

  @override
  String get ussdActionCashOutAgent => 'Retrait client (Cash-Out Agent)';

  @override
  String get ussdActionCashOutClient => 'Retrait d\'argent (Code client)';

  @override
  String get ussdActionTransfer => 'Transfert d\'argent';

  @override
  String get ussdActionMerchant => 'Paiement marchand';

  @override
  String get ussdActionBalanceAgent => 'Solde compte Agent/UV';

  @override
  String get ussdActionCredit => 'Achat crédit';

  @override
  String get ussdActionCashInAgent => 'Dépôt d\'argent (Cash-In Agent)';

  @override
  String get ussdActionBalanceFleet => 'Solde compte Flotte/Agent';

  @override
  String get ussdActionInternet => 'Achat forfait Internet';

  @override
  String get resetPasswordBtn => 'RÉINITIALISER';

  @override
  String get finalizeRegistration => 'Finalisation de l\'inscription';

  @override
  String get finalizeRegistrationDesc =>
      'Pour finaliser la création de votre compte via Google, veuillez renseigner les informations ci-dessous.';

  @override
  String get uniqueIdentifierDesc =>
      'Ceci est votre identifiant unique sur FIMUS';

  @override
  String get accountType => 'Type de compte';

  @override
  String get noAccountYet => 'Pas encore de compte ? ';

  @override
  String get registerNow => 'S\'inscrire';

  @override
  String get fullName => 'Nom complet';

  @override
  String get pleaseSelectCountry => 'Veuillez sélectionner votre pays';

  @override
  String get min8Chars => 'Minimum 8 caractères';

  @override
  String get professionalProfile => 'Professionnel';

  @override
  String get enableLock => 'Activer le verrouillage';

  @override
  String get enableLockDesc =>
      'Définissez un code PIN à 4 chiffres pour sécuriser l\'accès.';

  @override
  String get disableLock => 'Désactiver le verrouillage';

  @override
  String get disableLockDesc =>
      'Veuillez saisir votre code PIN actuel pour désactiver le verrouillage.';

  @override
  String get changePinCode => 'Modifier le code PIN';

  @override
  String get changePinCodeDesc => 'Changer votre code PIN à 4 chiffres';

  @override
  String get pinCodeChangedSuccess => 'Code PIN modifié avec succès';

  @override
  String get incorrectCurrentPinCode => 'Code PIN actuel incorrect';

  @override
  String get myUniqueId => 'Mon identifiant unique';

  @override
  String get uniqueIdCopied => 'Code unique copié !';

  @override
  String get manageContactsDesc =>
      'Gérer vos contacts pour le partage de comptes et dettes';

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get syncNowDesc => 'Pousse vos données locales vers le cloud';

  @override
  String get lockApp => 'Verrouiller l\'application';

  @override
  String get lockAppDesc => 'Sécuriser l\'accès avec un code PIN';

  @override
  String get unlockWithBiometrics => 'Déverrouiller avec la biométrie';

  @override
  String get errorMarkNotifRead =>
      'Erreur: impossible de marquer la notification comme lue.';

  @override
  String get errorMarkAllNotifRead =>
      'Erreur: impossible de marquer les notifications comme lues.';

  @override
  String get completeProfileTitle => 'Compléter votre profil';

  @override
  String get completeProfileSubtitle =>
      'Quelques informations supplémentaires sont requises';

  @override
  String get countryOfResidence => 'Pays de résidence';

  @override
  String get selectCountry => 'Sélectionnez un pays';

  @override
  String get pseudo => 'Pseudo';

  @override
  String get pseudoExample => 'Ex: marc123';

  @override
  String get countryRequired => 'Veuillez sélectionner un pays';

  @override
  String get finish => 'Terminer';

  @override
  String get pseudoRequired => 'Veuillez saisir un pseudo';

  @override
  String get pseudoLength => 'Le pseudo doit contenir entre 3 et 15 caractères';

  @override
  String get pseudoFormat =>
      'Seuls les lettres, chiffres, tirets et tirets bas sont autorisés';

  @override
  String get tooManyRequests =>
      'Trop de tentatives. Veuillez réessayer plus tard.';

  @override
  String tooManyRequestsRetry(String seconds) {
    return 'Trop de tentatives. Veuillez réessayer dans $seconds secondes.';
  }

  @override
  String get deleteUserAccount => 'Supprimer mon compte';

  @override
  String get deleteUserAccountConfirm => 'Supprimer le compte';

  @override
  String get deleteUserAccountWarning =>
      'Êtes-vous sûr de vouloir supprimer définitivement votre compte FIMUS ? Cette action est irréversible et supprimera l\'ensemble de vos données du serveur.';

  @override
  String get accountDeletedSuccess =>
      'Votre compte a été supprimé avec succès.';
}
