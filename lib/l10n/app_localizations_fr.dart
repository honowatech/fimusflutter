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
  String get yesterday => 'Hier';

  @override
  String get retry => 'Réessayer';

  @override
  String get errorFetchNotifications =>
      'Impossible de charger les notifications. Vérifiez votre connexion.';

  @override
  String get errorDeleteNotif => 'Erreur lors de la suppression.';

  @override
  String get markAllAsReadTooltip => 'Tout marquer comme lu';

  @override
  String get notifyAnnouncementsPref => 'Annonces et campagnes';

  @override
  String get notifyAnnouncementsPrefDesc =>
      'Recevoir les messages d\'information envoyés par FIMUS.';

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
  String get recentOperations => 'Actions rapides';

  @override
  String get last7Days => 'Les 7 derniers jours';

  @override
  String get incomeEntries => 'Entrées';

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
  String get notificationFallback => 'Nouvelle notification';

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
  String get catIncomePension => 'Pension Retraite';

  @override
  String get catIncomeFees => 'Honoraires';

  @override
  String get catIncomeProfits => 'Bénéfices';

  @override
  String get catIncomeDividends => 'Dividendes';

  @override
  String get catIncomeSale => 'Vente De Bien';

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
  String get myContacts => 'Mes contacts';

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

  @override
  String get tabOperations => 'Opérations';

  @override
  String get tabBreakdown => 'Synthèse & Pôles';

  @override
  String get spendingByPole => 'Répartition par pôle';

  @override
  String get spendingByMember => 'Répartition par membre';

  @override
  String get familyContributions => 'Contributions';

  @override
  String get shareWithContacts => 'Partager avec des contacts';

  @override
  String get selectContacts => 'Sélectionner des contacts';

  @override
  String get noContactsSelected => 'Aucun contact sélectionné';

  @override
  String get noContactFound => 'Aucun contact trouvé';

  @override
  String get linkedContacts => 'Contacts associés';

  @override
  String get accountSharedSuccessMultiple => 'Compte partagé avec succès !';

  @override
  String get filterAll => 'Tous les pôles';

  @override
  String get periodMonth => 'Ce mois';

  @override
  String get periodLastMonth => 'Mois dernier';

  @override
  String get period30Days => '30 derniers jours';

  @override
  String get periodYear => 'Cette année';

  @override
  String get periodCustom => 'Personnalisé';

  @override
  String get totalExpenses => 'Total dépenses';

  @override
  String get totalIncomes => 'Total recettes';

  @override
  String get netBalance => 'Solde net';

  @override
  String get noExpenseInPeriod => 'Aucune dépense sur cette période';

  @override
  String get addContactsToShare => 'Ajouter des contacts';

  @override
  String selectedContactsCount(int count) {
    return '$count contact(s) sélectionné(s)';
  }

  @override
  String get profileTypeSection => 'Profil d\'utilisation';

  @override
  String get currentProfileType => 'Type de profil actuel';

  @override
  String get switchToProfessional => 'Passer au profil Professionnel';

  @override
  String get switchToPersonal => 'Passer au profil Personnel';

  @override
  String get profileTypePermanent => 'Profil définitif';

  @override
  String get profileTypeAlreadyChanged =>
      'Vous avez déjà modifié votre profil. Ce choix est désormais irréversible.';

  @override
  String get profileTypeOneTimeHint => 'Changement unique autorisé';

  @override
  String get profileChangeTitle => 'Changer de profil ?';

  @override
  String get profileChangeToProfessionalDesc =>
      'En passant au profil Professionnel, vous aurez accès aux codes USSD Marchand / Agent, aux outils de tenue de caisse et de transactions commerciales.';

  @override
  String get profileChangeToPersonalDesc =>
      'En passant au profil Personnel, votre interface sera simplifiée et axée sur vos finances et dépenses personnelles.';

  @override
  String get profileChangeWarning =>
      'Attention : cette action est définitive. Vous ne pourrez plus revenir au profil précédent après confirmation.';

  @override
  String get confirmProfileChange => 'Confirmer le changement';

  @override
  String get profileChangeSuccess => 'Profil modifié avec succès';

  @override
  String get profileChangeError => 'Erreur lors du changement de profil';

  @override
  String get announcements => 'Annonces';

  @override
  String get enableNotificationsPrompt =>
      'Activez les notifications pour ne rien manquer.';

  @override
  String get batteryOptimizationPrompt =>
      'Pour recevoir les rappels à l\'heure, autorisez FIMUS à ignorer l\'optimisation de batterie.';

  @override
  String get onboardingNotificationsDenied =>
      'Notifications non autorisées. Vous pourrez les activer plus tard dans les réglages.';

  @override
  String get notifyDebtsPref => 'Dettes et remboursements';

  @override
  String get notifyDebtsPrefDesc =>
      'Alertes quand une dette partagée est créée, mise à jour ou refusée.';

  @override
  String get notifyContactsPref => 'Contacts';

  @override
  String get notifyContactsPrefDesc =>
      'Alertes lorsqu\'un proche vous ajoute à ses contacts.';

  @override
  String get notifyJointAccountsPref => 'Comptes conjoints';

  @override
  String get notifyJointAccountsPrefDesc =>
      'Alertes lorsqu\'on vous invite à un compte partagé.';

  @override
  String get confirmAndRegister => 'CONFIRMER ET S\'INSCRIRE';

  @override
  String get suggestionsLabel => 'Propositions :';

  @override
  String get unnamedContact => 'Un contact';

  @override
  String get debtDueNotifTitleDebt => '⏰ Rappel d\'échéance : Dette';

  @override
  String get debtDueNotifTitleReceivable => '⏰ Rappel d\'échéance : Créance';

  @override
  String debtDueNotifBodyDebt(String amount, String currency, String name) {
    return 'Votre dette de $amount $currency envers $name arrive à échéance aujourd\'hui.';
  }

  @override
  String debtDueNotifBodyReceivable(
    String amount,
    String currency,
    String name,
  ) {
    return 'Le remboursement de $amount $currency par $name arrive à échéance aujourd\'hui.';
  }

  @override
  String get scheduledExpenseNotifTitle => '⏰ Dépense programmée';

  @override
  String scheduledExpenseNotifBody(
    String title,
    String amount,
    String currency,
    String time,
  ) {
    return '« $title » · $amount $currency — prévue à $time. Touchez pour confirmer, modifier ou annuler.';
  }

  @override
  String get scheduledConfirmAction => 'Confirmer';

  @override
  String get scheduledCancelAction => 'Annuler';

  @override
  String get scheduledExpense => 'Dépense programmée';

  @override
  String get scheduledLabel => 'Programmées';

  @override
  String get addScheduledExpense => 'Ajouter une dépense programmée';

  @override
  String get editScheduledExpense => 'Modifier la dépense programmée';

  @override
  String get scheduledExpenses => 'Dépenses programmées';

  @override
  String get dateAndTime => 'Date et heure';

  @override
  String get confirmExpense => 'Confirmer la dépense';

  @override
  String get modify => 'Modifier';

  @override
  String get cancelScheduledExpense => 'Annuler la dépense programmée';

  @override
  String get cancelScheduledExpenseTitle => 'Annuler cette programmation ?';

  @override
  String get cancelScheduledExpenseBody =>
      'La dépense programmée sera supprimée et vous ne serez plus notifié(e).';

  @override
  String get futureDateRequired =>
      'La date et l\'heure doivent être dans le futur.';

  @override
  String get scheduledExpensesEmpty =>
      'Aucune dépense programmée pour le moment.';

  @override
  String get saveSchedule => 'Enregistrer la programmation';

  @override
  String get scheduleSaved =>
      'Dépense programmée enregistrée. Vous serez notifié(e) à l\'échéance.';

  @override
  String get scheduleUpdated => 'Programmation mise à jour.';

  @override
  String get scheduledExpenseConfirmed => 'Dépense confirmée ✅';

  @override
  String get scheduledExpenseCancelled => 'Dépense programmée annulée';

  @override
  String get confirmNow => 'Confirmer maintenant';

  @override
  String upcomingScheduledExpenses(int count) {
    return '$count dépense(s) programmée(s)';
  }

  @override
  String scheduledOn(String date) {
    return 'Prévue le : $date';
  }

  @override
  String scheduledTodayAt(String time) {
    return 'aujourd\'hui à $time';
  }

  @override
  String scheduledInDays(int days) {
    return 'dans $days jour(s)';
  }

  @override
  String get editExpense => 'Modifier la dépense';

  @override
  String get editIncome => 'Modifier le revenu';

  @override
  String get operationOptions => 'Options de l\'opération';

  @override
  String get detailsTitle => 'Détails de l\'opération';

  @override
  String get typeLabel => 'Type';

  @override
  String get operationDate => 'Date de l\'opération';

  @override
  String get recordedDate => 'Date d\'enregistrement';

  @override
  String get recordedBy => 'Enregistrée par';

  @override
  String get linkedAccount => 'Compte lié';

  @override
  String get noteLabel => 'Note';

  @override
  String get noNote => 'Aucune note';

  @override
  String get me => 'Moi';

  @override
  String get status => 'Statut';

  @override
  String get dueDateLabel => 'Échéance';

  @override
  String get debtTagLabel => 'Personne concernée';

  @override
  String get debtStatusPending => 'En attente';

  @override
  String get debtStatusAccepted => 'Acceptée';

  @override
  String sharedAccountOperationBy(String name) {
    return 'Opération enregistrée sur ce compte partagé par $name';
  }

  @override
  String get myAccount => 'Mon Compte';

  @override
  String get user => 'Utilisateur';

  @override
  String get myPseudo => 'Mon pseudo';

  @override
  String get notDefined => 'Non défini';

  @override
  String get pseudoCopied => 'Mon pseudo copié !';

  @override
  String syncComplete(int pushed, int pulled) {
    return 'Sync terminée — $pushed envoyés, $pulled reçus';
  }

  @override
  String syncError(String message) {
    return 'Erreur : $message';
  }

  @override
  String get logoutTitle => 'Déconnexion';

  @override
  String get logoutConfirmBody =>
      'Êtes-vous sûr de vouloir vous déconnecter ? Vos données locales seront préservées.';

  @override
  String get loginToSync =>
      'Connectez-vous pour synchroniser vos données dans le cloud.';

  @override
  String get accessSecurity => 'Sécurité d\'accès';

  @override
  String get fingerprintFaceId => 'Empreinte / Face ID';

  @override
  String get enter4Digits => 'Saisissez 4 chiffres';

  @override
  String get pinCodesDoNotMatch => 'Les codes ne correspondent pas';

  @override
  String get pinRequired => 'Code PIN requis';

  @override
  String get environmentDevMode => 'Environnement & Mode Dev';

  @override
  String get devModeLocalDb => 'Mode Développeur (BD Locale)';

  @override
  String get productionMode => 'Mode Production (PlayStore)';

  @override
  String connectedToLocalDb(String url) {
    return 'Connecté à la base locale : $url';
  }

  @override
  String get connectedToOnlineServer =>
      'Connecté au serveur en ligne sécurisé (PlayStore)';

  @override
  String get enableDevModeTitle => 'Activer le mode Dev ?';

  @override
  String get enableDevModeBody =>
      'En mode Dev, l\'application se connecte à votre base de données locale (Laravel local) et isole les données dans monitrack_dev.db.\n\nVous pourrez repasser en mode Production à tout moment avant la publication PlayStore.';

  @override
  String get enableDevModeBtn => 'Activer Mode Dev';

  @override
  String localDbInfo(String db, String url) {
    return 'Base locale active: $db\nURL API: $url';
  }

  @override
  String get localEnvType => 'Type d\'environnement local :';

  @override
  String get hostVhost => 'Host fimus.local (Recommandé)';

  @override
  String get hostEmulator => 'Émulateur Android (10.0.2.2)';

  @override
  String get hostWeb => 'Localhost / Web';

  @override
  String get hostCustom => 'IP / URL personnalisée';

  @override
  String get localApiUrlLabel => 'URL de l\'API Locale (Serveur Laravel)';

  @override
  String get localApiUrlHint =>
      'http://fimus.local/api ou http://192.168.1.50:8000/api';

  @override
  String get localApiUrlHelper =>
      'Indiquez l\'adresse de votre serveur local (ex: http://fimus.local/api ou IP WiFi).';

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get devHostApply => 'Appliquer';

  @override
  String get resetToLaunchProfile => 'Revenir au profil de lancement';

  @override
  String connectionTestOk(int ms) {
    return 'Connexion réussie ($ms ms)';
  }

  @override
  String connectionTestHttpStatus(int code) {
    return 'Le serveur a répondu avec le code $code';
  }

  @override
  String get connectionTestTimeout =>
      'Délai dépassé (> 4 s). Vérifiez l\'URL ou le serveur.';

  @override
  String get connectionTestRefused =>
      'Connexion refusée. Le serveur local est-il démarré ?';

  @override
  String connectionTestError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get purgeTestDbTitle => 'Purger la base locale de test ?';

  @override
  String get purgeTestDbBody =>
      'Cette action supprime les données de test de monitrack_dev.db. Votre base de production ne sera pas affectée.';

  @override
  String get purge => 'Purger';

  @override
  String get purgeTests => 'Purger tests';

  @override
  String get backToProduction => 'Retour Production';

  @override
  String get allCategoriesSelected => 'Catégories';

  @override
  String categoriesSelectedCount(int count) {
    return '$count catégories';
  }

  @override
  String get filterByCategory => 'Filtrer par catégorie';

  @override
  String get accountsDesc => 'Comptes connectés sur cet appareil';

  @override
  String accountsCount(int count) {
    return '$count comptes connectés';
  }

  @override
  String get addAccountSubtitle =>
      'Connectez un autre compte MoniTrack sur cet appareil';

  @override
  String get activeAccount => 'Actif';

  @override
  String deviceAccountLimit(int max) {
    return 'Vous pouvez connecter jusqu\'à $max comptes sur cet appareil. Déconnectez un compte pour en ajouter un autre.';
  }

  @override
  String createCategory(String name) {
    return 'Créer « $name »';
  }

  @override
  String get notificationSettingsTitle => 'Notifications';

  @override
  String get notificationSettingsSubtitle =>
      'Autorisations, catégories et heures calmes';

  @override
  String get notificationPermissionSection => 'Autorisation système';

  @override
  String get notificationPermissionGranted => 'Notifications autorisées';

  @override
  String get notificationPermissionGrantedDesc =>
      'FIMUS peut vous alerter en temps réel.';

  @override
  String get notificationPermissionDenied => 'Notifications bloquées';

  @override
  String get notificationPermissionDeniedDesc =>
      'Sans autorisation, les rappels d\'échéance et les alertes de dettes partagées ne s\'afficheront pas.';

  @override
  String get notificationPermissionUnknown => 'Autorisation non vérifiée';

  @override
  String get notificationPermissionUnknownDesc =>
      'Vérifiez l\'état de l\'autorisation pour recevoir les alertes.';

  @override
  String get notificationPermissionCheck => 'Vérifier';

  @override
  String get notificationPermissionOpenSettings => 'Ouvrir les réglages';

  @override
  String get notificationPermissionSettingsHint =>
      'Le système ne redemandera plus. Activez les notifications depuis les réglages de l\'application.';

  @override
  String get notificationPermissionRationaleTitle =>
      'Activer les notifications ?';

  @override
  String get notificationPermissionRationaleBody =>
      'FIMUS vous prévient à l\'échéance d\'une dette, quand un proche vous ajoute à un compte partagé et avant une dépense programmée. Aucune notification publicitaire n\'est envoyée sans votre accord.';

  @override
  String get notificationPermissionRationaleConfirm => 'Autoriser';

  @override
  String get notificationPermissionRationaleDismiss => 'Plus tard';

  @override
  String get notificationCategoriesSection => 'Catégories';

  @override
  String get notifyScheduledExpensesPref => 'Dépenses programmées';

  @override
  String get notifyScheduledExpensesPrefDesc =>
      'Rappels avant le prélèvement d\'une dépense récurrente.';

  @override
  String get reminderScheduleSection => 'Rappels';

  @override
  String get reminderHourTitle => 'Heure des rappels';

  @override
  String get reminderHourDesc =>
      'Heure à laquelle les rappels d\'échéance sont envoyés.';

  @override
  String get quietHoursTitle => 'Heures calmes';

  @override
  String get quietHoursDesc =>
      'Suspendre les notifications pendant une plage horaire.';

  @override
  String get quietHoursStartLabel => 'Début';

  @override
  String get quietHoursEndLabel => 'Fin';

  @override
  String get quietHoursOvernightHint => 'La plage se poursuit après minuit.';

  @override
  String get exactAlarmsTitle => 'Alarmes exactes';

  @override
  String get exactAlarmsDesc =>
      'Nécessaires pour déclencher les rappels à l\'heure précise. Sans elles, Android peut les retarder de plusieurs heures.';

  @override
  String get exactAlarmsGranted => 'Autorisées';

  @override
  String get exactAlarmsMissing => 'Non autorisées';

  @override
  String get exactAlarmsAllow => 'Autoriser';

  @override
  String get notificationPreferencesLoadError =>
      'Impossible de charger vos préférences de notification.';

  @override
  String get notificationPreferencesSaveError =>
      'Impossible d\'enregistrer la modification. Elle a été annulée.';

  @override
  String get notificationPreferencesOfflineHint =>
      'Valeurs enregistrées sur cet appareil, affichées hors connexion.';

  @override
  String get offlineBanner => 'Hors ligne · données locales';

  @override
  String offlineBannerWithDate(String date) {
    return 'Hors ligne · données du $date';
  }

  @override
  String get notifChannelDebtsName => 'Dettes et remboursements';

  @override
  String get notifChannelDebtsDesc =>
      'Dettes partagées, remboursements et rappels d\'échéance.';

  @override
  String get notifChannelScheduledExpensesName => 'Dépenses programmées';

  @override
  String get notifChannelScheduledExpensesDesc =>
      'Rappels des dépenses que vous avez programmées.';

  @override
  String get notifChannelContactsName => 'Contacts';

  @override
  String get notifChannelContactsDesc =>
      'Alertes lorsqu\'un proche vous ajoute à ses contacts.';

  @override
  String get notifChannelJointAccountsName => 'Comptes conjoints';

  @override
  String get notifChannelJointAccountsDesc =>
      'Invitations et activité des comptes partagés.';

  @override
  String get notifChannelGeneralName => 'Général';

  @override
  String get notifChannelGeneralDesc => 'Notifications de service FIMUS.';

  @override
  String get notifChannelAnnouncementsName => 'Annonces';

  @override
  String get notifChannelAnnouncementsDesc =>
      'Nouveautés, conseils et offres FIMUS. Sans son.';

  @override
  String get loadMore => 'Charger plus';

  @override
  String get notificationFilterContacts => 'Contacts';

  @override
  String get notificationFilterScheduled => 'Programmées';

  @override
  String get notificationSectionEarlier => 'Plus tôt';

  @override
  String get notificationUnreadBadge => 'Non lu';

  @override
  String get notificationReadBadge => 'Lu';

  @override
  String get notificationTimeJustNow => 'À l\'instant';

  @override
  String notificationTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count min',
      one: 'il y a $count min',
    );
    return '$_temp0';
  }

  @override
  String notificationTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count h',
      one: 'il y a $count h',
    );
    return '$_temp0';
  }

  @override
  String get notificationDeleted => 'Notification supprimée';

  @override
  String get undoAction => 'Annuler';

  @override
  String get clearSelectionTooltip => 'Quitter la sélection';

  @override
  String notificationsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnées',
      one: '$count sélectionnée',
    );
    return '$_temp0';
  }

  @override
  String get notificationsEmptyForFilter =>
      'Aucune notification dans cette catégorie.';

  @override
  String get notificationsShowAllFilters => 'Voir toutes les notifications';

  @override
  String get displayMode => 'Mode d\'affichage';

  @override
  String get displayModeSubtitle => 'Choisissez l\'apparence de l\'application';

  @override
  String get themeModeSystem => 'Système';

  @override
  String get themeModeLight => 'Clair';

  @override
  String get themeModeDark => 'Sombre';

  @override
  String get notifChannelAlertsName => 'Alertes de finances';

  @override
  String get notifChannelAlertsDesc =>
      'Budget atteint, solde bas, données en attente d\'envoi';

  @override
  String get alertBudgetWarningTitle => 'Budget bientôt atteint';

  @override
  String alertBudgetWarningBody(
    String category,
    int percent,
    String spent,
    String budget,
    String currency,
  ) {
    return '$category : $percent % du budget consommé ($spent / $budget $currency) ce mois-ci.';
  }

  @override
  String get alertBudgetReachedTitle => 'Budget dépassé';

  @override
  String alertBudgetReachedBody(
    String category,
    int percent,
    String spent,
    String budget,
    String currency,
  ) {
    return '$category : $percent % du budget consommé ($spent / $budget $currency) ce mois-ci.';
  }

  @override
  String get alertLowBalanceTitle => 'Solde bas';

  @override
  String alertLowBalanceBody(
    String account,
    String balance,
    String threshold,
    String currency,
  ) {
    return '$account : $balance $currency, sous votre seuil de $threshold $currency.';
  }

  @override
  String get alertUnsyncedTitle => 'Données non synchronisées';

  @override
  String alertUnsyncedBody(int count, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count opérations en attente depuis $hours h. Synchronisez pour ne rien perdre.',
      one:
          '1 opération en attente depuis $hours h. Synchronisez pour ne rien perdre.',
    );
    return '$_temp0';
  }

  @override
  String get localAlertsSection => 'Alertes personnalisées';

  @override
  String get alertsLocalOnlyNotice =>
      'Ces réglages sont enregistrés sur cet appareil uniquement : ils ne suivent pas votre compte sur un autre téléphone.';

  @override
  String get alertBudgetSwitchTitle => 'Seuil de budget';

  @override
  String get alertBudgetSwitchDesc =>
      'Vous prévenir à 80 % puis à 100 % du budget mensuel d\'une catégorie';

  @override
  String get alertLowBalanceSwitchTitle => 'Solde bas';

  @override
  String get alertLowBalanceSwitchDesc =>
      'Vous prévenir quand un compte passe sous son seuil';

  @override
  String get alertUnsyncedSwitchTitle => 'Données non synchronisées';

  @override
  String get alertUnsyncedSwitchDesc =>
      'Vous prévenir quand des opérations attendent trop longtemps d\'être envoyées';

  @override
  String get alertBudgetsManageTitle => 'Budgets mensuels par catégorie';

  @override
  String get alertThresholdsManageTitle => 'Seuils de solde par compte';

  @override
  String get alertTrackedNone => 'Aucun suivi configuré';

  @override
  String alertBudgetsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count catégories suivies',
      one: '1 catégorie suivie',
    );
    return '$_temp0';
  }

  @override
  String alertThresholdsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comptes suivis',
      one: '1 compte suivi',
    );
    return '$_temp0';
  }

  @override
  String get alertUnsyncedDelayTitle => 'Délai avant alerte';

  @override
  String alertUnsyncedDelayValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get alertBudgetsDialogTitle => 'Budgets mensuels';

  @override
  String get alertThresholdsDialogTitle => 'Seuils de solde bas';

  @override
  String get alertBudgetFieldLabel => 'Budget mensuel';

  @override
  String get alertThresholdFieldLabel => 'Seuil d\'alerte';

  @override
  String get alertValueNotSet => 'Non défini';

  @override
  String get alertNoCategories => 'Aucune catégorie de dépense disponible.';

  @override
  String get alertNoAccounts => 'Aucun compte disponible.';

  @override
  String get alertInvalidAmount => 'Saisissez un montant valide.';

  @override
  String get alertResetStateTitle => 'Réinitialiser les alertes déjà envoyées';

  @override
  String get alertResetStateDesc =>
      'Autorise à nouveau les alertes déjà reçues ce mois-ci';

  @override
  String get alertResetStateDone => 'Alertes réinitialisées';

  @override
  String get savingInProgress => 'Enregistrement en cours...';

  @override
  String get savedLocallyWillSync =>
      'L\'opération a été enregistrée sur votre téléphone. Elle sera synchronisée dès le retour de la connexion internet.';

  @override
  String get genericErrorRetry =>
      'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get debtOpCollectRepaymentTitle => 'Percevoir un remboursement';

  @override
  String get debtOpRepayDebtTitle => 'Rembourser une dette';

  @override
  String get debtOpNewBorrowTitle => 'Nouvel emprunt (Dette)';

  @override
  String get debtOpNewLoanTitle => 'Nouveau prêt (Créance)';

  @override
  String debtOpCollectFromHint(String name) {
    return 'Percevoir un remboursement de la part de $name';
  }

  @override
  String debtOpRepayToHint(String name) {
    return 'Rembourser la dette envers $name';
  }

  @override
  String get debtOpSettledSuffix => '(Soldé)';

  @override
  String debtOpTotalToRepay(String amount, String currency) {
    return 'Total à rembourser : $amount $currency';
  }

  @override
  String get receivableInterestSimulator => 'Créance avec intérêt (Simulateur)';

  @override
  String get debtOpNoCashFlowImpact =>
      'Cette opération est purement indicative et n\'impactera ni vos comptes, ni vos statistiques.';

  @override
  String get debtOpNoLinkableAccount =>
      'Aucun compte disponible pour être lié.';

  @override
  String get pleaseChooseAccount => 'Veuillez choisir un compte';

  @override
  String get debtOpSetDueDate => 'Définir une date d\'échéance';

  @override
  String get debtOpSetDueDateDesc => 'Date limite de remboursement recommandée';

  @override
  String get debtOpDueDatePlanned => 'Date d\'échéance prévue';

  @override
  String get selectDate => 'Sélectionner une date';

  @override
  String get frequencyMonthly => 'Mensuelle';

  @override
  String get frequencyWeekly => 'Hebdomadaire';

  @override
  String get frequencyDaily => 'Quotidienne';

  @override
  String get frequencyAnnual => 'Annuelle';

  @override
  String get debtBadgeSettled => 'Soldé';

  @override
  String get debtBadgeToRepay => 'Dette à rembourser';

  @override
  String get debtBadgeToCollect => 'Créance à encaisser';

  @override
  String get filterLabel => 'Filtre :';

  @override
  String get validate => 'Valider';

  @override
  String get debtKind => 'Dette';

  @override
  String get receivableKind => 'Créance';

  @override
  String get createdByMe => 'Moi';

  @override
  String get createdByMember => 'Membre';

  @override
  String get debtNewOperationTitle => 'Nouvelle opération de dette';

  @override
  String get debtSelectTitle => 'Sélectionner une dette';

  @override
  String get someone => 'Quelqu\'un';

  @override
  String debtPendingInvitation(String name, String title) {
    return '$name vous a associé à une dette : $title';
  }

  @override
  String debtDueDateOverdue(String date) {
    return 'Échéance dépassée : $date';
  }

  @override
  String debtDueDatePlanned(String date) {
    return 'Échéance prévue : $date';
  }

  @override
  String debtDueDateValue(String date) {
    return 'Échéance : $date';
  }

  @override
  String get selectPeriod => 'Sélectionner une période';

  @override
  String get selectPeriodMax6Months => 'Sélectionner une période (max 6 mois)';

  @override
  String operationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opérations',
      one: '$count opération',
    );
    return '$_temp0';
  }

  @override
  String get exampleLabel => 'Exemple :';

  @override
  String get ussdQuickInsertChips => 'Puces d\'insertion rapide :';

  @override
  String get ussdPreviewTitle => 'Aperçu de l\'écran d\'exécution';

  @override
  String ussdPreviewEmptyHint(String first, String second) {
    return 'Saisissez un code USSD contenant des variables comme $first ou $second pour générer l\'aperçu.';
  }

  @override
  String get ussdAmountToTransferLabel => 'Montant à transférer';

  @override
  String get productPhotoTitle => 'Photo du produit';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get chooseFromGallery => 'Choisir dans la galerie';

  @override
  String get deletePhoto => 'Supprimer la photo';

  @override
  String get addPhoto => 'Ajouter photo';

  @override
  String get productUpdated => 'Produit mis à jour';

  @override
  String get productSaved => 'Produit enregistré avec succès';

  @override
  String get editProductTitle => 'Modifier le produit';

  @override
  String get newProductTitle => 'Nouveau produit';

  @override
  String get productNameLabel => 'Nom du produit *';

  @override
  String get productNameHint => 'Ex : Sac de riz 25 kg, Téléphone…';

  @override
  String get productNameRequired => 'Veuillez entrer le nom du produit';

  @override
  String productPriceLabel(String currency) {
    return 'Prix de vente ($currency) *';
  }

  @override
  String get productPriceRequired => 'Veuillez entrer le prix';

  @override
  String get productPriceInvalid => 'Prix invalide';

  @override
  String get productDescriptionLabel => 'Description (optionnelle)';

  @override
  String get productDescriptionHint =>
      'Détails, taille, couleur, conditionnement…';

  @override
  String get updateAction => 'METTRE À JOUR';

  @override
  String get saveProductAction => 'ENREGISTRER LE PRODUIT';

  @override
  String get staffUpdated => 'Membre mis à jour';

  @override
  String get staffAdded => 'Collaborateur ajouté avec succès';

  @override
  String get editStaffTitle => 'Modifier le collaborateur';

  @override
  String get newStaffTitle => 'Nouveau collaborateur';

  @override
  String get staffNameLabel => 'Nom & Prénom *';

  @override
  String get staffNameHint => 'Ex : Amadou Diallo';

  @override
  String get staffNameRequired => 'Veuillez entrer le nom';

  @override
  String get staffRoleLabel => 'Rôle / Poste';

  @override
  String get staffRoleHint => 'Ex : Comptable, Commercial, Technicien…';

  @override
  String get phoneNumberLabel => 'Numéro de téléphone';

  @override
  String get staffPhoneHint => 'Ex : +221 77 123 45 67';

  @override
  String get emailAddressLabel => 'Adresse Email';

  @override
  String get staffEmailHint => 'Ex : amadou@entreprise.com';

  @override
  String staffSalaryLabel(String currency) {
    return 'Rémunération mensuelle ($currency)';
  }

  @override
  String get addStaffAction => 'AJOUTER LE COLLABORATEUR';

  @override
  String get deleteProductTitle => 'Supprimer ce produit ?';

  @override
  String deleteProductConfirm(String name) {
    return 'Voulez-vous vraiment supprimer « $name » ?';
  }

  @override
  String productDeleted(String name) {
    return 'Produit « $name » supprimé';
  }

  @override
  String get searchProductHint => 'Rechercher un produit…';

  @override
  String productsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits',
      one: '$count produit',
    );
    return '$_temp0';
  }

  @override
  String get noProductFound => 'Aucun produit trouvé';

  @override
  String get emptyCatalog => 'Votre catalogue est vide';

  @override
  String get trySearchAgain => 'Essayez une autre recherche.';

  @override
  String get emptyCatalogHint =>
      'Enregistrez vos articles pour gérer vos ventes rapidement.';

  @override
  String get addFirstProduct => 'Ajouter mon premier produit';

  @override
  String get deleteStaffTitle => 'Supprimer ce collaborateur ?';

  @override
  String deleteStaffConfirm(String name) {
    return 'Voulez-vous vraiment retirer « $name » de votre équipe ?';
  }

  @override
  String staffDeleted(String name) {
    return 'Collaborateur « $name » supprimé';
  }

  @override
  String get searchStaffHint => 'Rechercher un membre de l\'équipe…';

  @override
  String staffCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborateurs',
      one: '$count collaborateur',
    );
    return '$_temp0';
  }

  @override
  String get noStaffFound => 'Aucun collaborateur trouvé';

  @override
  String get noStaffRecorded => 'Aucun collaborateur enregistré';

  @override
  String get emptyStaffHint =>
      'Organisez votre équipe, les rôles et contacts professionnels.';

  @override
  String get addStaffMember => 'Ajouter un collaborateur';

  @override
  String get googleSignInInterrupted => 'Connexion interrompue, réessayez.';

  @override
  String get googleSignInNoAccount =>
      'Aucun compte Google trouvé. Ajoutez-en un ou utilisez email/mot de passe.';

  @override
  String get googleSignInUnavailable =>
      'Configuration indisponible. Veuillez réessayer plus tard.';

  @override
  String get googleSignInUpdatePlayServices =>
      'Mettez à jour Google Play Services.';

  @override
  String get googleSignInAccountChanged =>
      'Changement de compte détecté, réessayez.';

  @override
  String get googleSignInGenericError =>
      'La connexion Google a échoué. Veuillez réessayer.';

  @override
  String get forgotPasswordSent =>
      'Un nouveau mot de passe a été envoyé à votre adresse email. Veuillez vérifier vos spams si le message n\'est pas dans la boîte principale.';

  @override
  String get loginSubtitle => 'Connectez-vous pour gérer vos finances';

  @override
  String get loginAction => 'SE CONNECTER';

  @override
  String get orSeparator => 'OU';

  @override
  String get noAccountQuestion => 'Vous n\'avez pas de compte ? ';

  @override
  String get haveAccountQuestion => 'Vous avez déjà un compte ? ';

  @override
  String get registerAccountAction => 'CRÉER MON COMPTE';

  @override
  String get registerSubtitle => 'Créez votre compte en quelques secondes';

  @override
  String get registerSuccessEmailSent =>
      'Compte créé ! Votre mot de passe vous a été envoyé par email afin de ne pas l\'oublier.';

  @override
  String get startAction => 'DÉMARRER';

  @override
  String get back => 'Retour';

  @override
  String onboardingStepProgress(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get onboardingCountryHint =>
      'FIMUS adapte vos opérateurs et codes USSD en fonction de votre localisation.';

  @override
  String get onboardingProfileTypeHint =>
      'Sélectionnez votre type d\'utilisation pour adapter l\'interface.';

  @override
  String get profileTypePersonal => 'Personnel';

  @override
  String get profileTypeSmallBusiness => 'Petit commerce';

  @override
  String get profileTypeSmallBusinessShort => 'Commerce';

  @override
  String get profileTypeSmallBusinessDesc => 'Vente & Produits';

  @override
  String get profileTypeCompany => 'Entreprise';

  @override
  String get profileTypeCompanyDesc => 'Services & Équipe';

  @override
  String get profileTypeKiosk => 'Kiosque';

  @override
  String get profileTypeKioskDesc => 'Transfert d\'argent';

  @override
  String get lockTooManyAttemptsReauth =>
      'Trop de tentatives. Reconnectez-vous avec votre mot de passe.';

  @override
  String lockTooManyAttemptsRetryIn(String delay) {
    return 'Trop de tentatives. Réessayez dans $delay.';
  }

  @override
  String get verifying => 'Vérification…';

  @override
  String lockIncorrectPinAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Code PIN incorrect · $count essais avant blocage',
      one: 'Code PIN incorrect · $count essai avant blocage',
    );
    return '$_temp0';
  }

  @override
  String get enterYourPin => 'Saisissez votre code PIN';

  @override
  String get securityTitle => 'Sécurité';

  @override
  String get lockFullReauthBody =>
      'Trop de codes PIN erronés ont été saisis. Pour votre sécurité, reconnectez-vous avec votre mot de passe. Vos données locales sont conservées.';

  @override
  String get reconnectAction => 'Se reconnecter';

  @override
  String get lockForgotPinBody =>
      'Pour des raisons de sécurité, si vous avez oublié votre code PIN, vous devez vous déconnecter et vous reconnecter. Vos données locales synchronisées seront préservées.';

  @override
  String get ussdLoadingCodes => 'Chargement des codes USSD…';

  @override
  String get ussdNoOperatorAvailable => 'Aucun opérateur disponible';

  @override
  String get ussdSelectCountryOrAddOperator =>
      'Sélectionnez un pays ou ajoutez un opérateur';

  @override
  String get ussdAddOperatorSubtitle =>
      'Configurez un nouvel opérateur télécom pour vos codes USSD';

  @override
  String get ussdHiddenBadge => 'Masqué';

  @override
  String get ussdHideOperation => 'Masquer l\'opération';

  @override
  String get ussdShowOperation => 'Afficher l\'opération';

  @override
  String get navProducts => 'Produits';

  @override
  String get navStaff => 'Équipe';

  @override
  String get changeProfileAction => 'Changer de profil';

  @override
  String get profileTypeChooseNew => 'Choisir un nouveau profil';

  @override
  String get profileTypeChangeWarningOnce =>
      'Attention : ce changement est unique et définitif.';

  @override
  String get profileChangeToSmallBusinessDesc =>
      'En passant au profil Petit commerce, vous aurez accès au catalogue de produits pour enregistrer et suivre vos articles en vente.';

  @override
  String get profileChangeToCompanyDesc =>
      'En passant au profil Entreprise, vous aurez accès au module Staff pour gérer vos collaborateurs, postes et contacts d\'équipe.';

  @override
  String get profileChangeToKioskDesc =>
      'En passant au profil Kiosque, vous aurez accès aux codes USSD Marchand / Agent et aux outils de tenue de caisse Mobile Money.';

  @override
  String get announcementFallback1 =>
      'Configurez vos codes USSD préférés pour exécuter vos transactions en un seul clic !';

  @override
  String get announcementFallback2 =>
      'Vous pouvez désormais ajouter ou supprimer vos opérateurs USSD personnalisés en toute simplicité.';

  @override
  String get announcementFallback3 =>
      'Suivi de budget : Suivez vos dépenses quotidiennes et maîtrisez votre budget grâce à nos rapports détaillés.';

  @override
  String get notifyWeeklyDigestPref => 'Bilan hebdomadaire';

  @override
  String get notifyWeeklyDigestPrefDesc =>
      'Résumé de vos dépenses de la semaine, envoyé chaque dimanche.';

  @override
  String get newLoginConfirmTitle => 'Ce n\'était pas vous ?';

  @override
  String get newLoginConfirmBody =>
      'Toutes les autres sessions de votre compte seront déconnectées. Cet appareil restera connecté.';

  @override
  String newLoginConfirmBodyWithDetails(String details) {
    return 'Connexion détectée : $details.\n\nToutes les autres sessions de votre compte seront déconnectées. Cet appareil restera connecté.';
  }

  @override
  String get newLoginConfirmAction => 'Ce n\'était pas moi';

  @override
  String revokeOtherSessionsDone(int sessions, int devices) {
    return '$sessions session(s) et $devices appareil(s) déconnectés. Changez votre mot de passe si vous ne reconnaissez pas cette connexion.';
  }

  @override
  String get revokeOtherSessionsError =>
      'La révocation a échoué. Vérifiez votre connexion, puis réessayez depuis les réglages de sécurité.';
}
