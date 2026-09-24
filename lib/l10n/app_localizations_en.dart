// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FIMUS';

  @override
  String get settings => 'Settings';

  @override
  String get preferences => 'Preferences';

  @override
  String get operators => 'Operators';

  @override
  String get ussdCodes => 'USSD Codes';

  @override
  String get ussdCategories => 'USSD Categories';

  @override
  String get expenseCategories => 'Expense Categories';

  @override
  String get appLanguage => 'App Language';

  @override
  String get currency => 'Currency';

  @override
  String get french => 'Français';

  @override
  String get english => 'English';

  @override
  String get addOperator => 'Add an operator';

  @override
  String get addUssdCodeFor => 'Add a USSD code for:';

  @override
  String get noOperatorAvailable => 'No operator available. Add one first.';

  @override
  String get addExpenseCategory => 'Add an expense category';

  @override
  String get addUssdCategory => 'Add a USSD category';

  @override
  String get categoryName => 'Category name';

  @override
  String get addNew => 'Add New';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get editOperator => 'Edit operator';

  @override
  String get country => 'Country';

  @override
  String get allCountries => 'All countries';

  @override
  String get sortByCountry => 'Sort by country';

  @override
  String get operatorName => 'Operator name';

  @override
  String get yourPhoneNumber => 'Your phone number';

  @override
  String get save => 'Save';

  @override
  String get deleteOperator => 'Delete operator';

  @override
  String deleteOperatorConfirm(String name) {
    return 'Are you sure you want to delete the operator $name? All associated USSD operations will also be deleted.';
  }

  @override
  String get deleteOperation => 'Delete operation';

  @override
  String deleteOperationConfirm(String name) {
    return 'Are you sure you want to delete the operation $name?';
  }

  @override
  String get delete => 'Delete';

  @override
  String myNumber(String number) {
    return 'My number: $number';
  }

  @override
  String get noNumberDefined => 'No number defined';

  @override
  String availableVariables(String variables) {
    return 'Available variables: $variables';
  }

  @override
  String get ussdTemplate => 'USSD Code Template';

  @override
  String get codeUpdatedSuccess => 'Code updated successfully';

  @override
  String get resetToDefault => 'Reset';

  @override
  String get codeResetSuccess => 'Code reset to default';

  @override
  String get cannotDeleteOther => 'The \'Autre\' category cannot be deleted';

  @override
  String get expenses => 'Expenses';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get history => 'History';

  @override
  String get accounts => 'Accounts';

  @override
  String get newOperation => 'New operation';

  @override
  String get ussdMenu => 'USSD';

  @override
  String get expense => 'Expense';

  @override
  String get income => 'Income';

  @override
  String get monthOverview => 'Month overview';

  @override
  String get incomes => 'Incomes';

  @override
  String get yourAccounts => 'Your Accounts';

  @override
  String get totalBalance => 'Total Balance';

  @override
  String get noAccountSaved => 'No account saved.';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get retry => 'Retry';

  @override
  String get errorFetchNotifications =>
      'Unable to load notifications. Check your connection.';

  @override
  String get errorDeleteNotif => 'Error while deleting.';

  @override
  String get markAllAsReadTooltip => 'Mark all as read';

  @override
  String get notifyAnnouncementsPref => 'Announcements and campaigns';

  @override
  String get notifyAnnouncementsPrefDesc =>
      'Receive information messages sent by FIMUS.';

  @override
  String get thisWeek => 'This week';

  @override
  String get thisMonth => 'This month';

  @override
  String get all => 'All';

  @override
  String get noOperationPeriod => 'No operation for this period.';

  @override
  String get addAccount => 'Add account';

  @override
  String get editAccount => 'Edit account';

  @override
  String get accountName => 'Account name (e.g., Cash, Bank)';

  @override
  String get initialBalance => 'Initial balance';

  @override
  String get deleteAccountConfirm => 'Delete this account?';

  @override
  String get irreversibleAction => 'This action is irreversible.';

  @override
  String get addIncome => 'Add income';

  @override
  String get addExpense => 'Add expense';

  @override
  String get title => 'Title';

  @override
  String get required => 'Required';

  @override
  String get amount => 'Amount';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String get category => 'Category';

  @override
  String get pleaseChooseCategory => 'Please choose a category';

  @override
  String get linkedAccountOptional => 'Linked account (Optional)';

  @override
  String get noAccount => 'No account';

  @override
  String get date => 'Date';

  @override
  String get saveIncome => 'Save income';

  @override
  String get saveExpense => 'Save expense';

  @override
  String get finishReorder => 'Finish reordering';

  @override
  String get reorderOperations => 'Reorder operations';

  @override
  String get noOperationForOperator => 'No operation for this operator.';

  @override
  String get editOperation => 'Edit operation';

  @override
  String get operationName => 'Operation name';

  @override
  String get ussdCodeExample => 'USSD Code (e.g. *126#)';

  @override
  String get recipientNumber => 'Recipient number';

  @override
  String amountToTransfer(String currency) {
    return 'Amount to transfer ($currency)';
  }

  @override
  String get merchantCode => 'Merchant code';

  @override
  String limitPerOperation(String currency) {
    return 'Limit: 500,000 $currency per operation';
  }

  @override
  String feeFlat3333(String currency) {
    return '54 $currency flat';
  }

  @override
  String feePercent266666(String currency) {
    return '1.5% + 4 $currency (flat rate)';
  }

  @override
  String feeFlatMax(String currency) {
    return '4,004 $currency flat';
  }

  @override
  String get enterAmountToSeeFees =>
      'Enter an amount to see the fees breakdown';

  @override
  String get feesBreakdown => 'Fees breakdown';

  @override
  String get amountToSend => 'Amount to send';

  @override
  String withdrawalFees(String label) {
    return 'Withdrawal fees ($label)';
  }

  @override
  String get ttaTax => 'TTA (0.2% — finance law 2022)';

  @override
  String get totalFees => 'Total fees';

  @override
  String get amountDebited => 'Amount debited';

  @override
  String operatorLabel(String name) {
    return 'Operator: $name';
  }

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get pleaseEnterValidAmount => 'Please enter a valid amount';

  @override
  String regulatoryLimitExceeded(String currency) {
    return 'The regulatory limit is 500,000 $currency per operation';
  }

  @override
  String get includeWithdrawalFees => 'Include withdrawal fees';

  @override
  String get buyForAnother => 'Buy for someone else';

  @override
  String get executeOperation => 'Execute operation';

  @override
  String get allLabel => 'All';

  @override
  String get noHistory => 'No history.';

  @override
  String noHistoryForOperator(String operator) {
    return 'No history for $operator.';
  }

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortByDate => 'Sort by date';

  @override
  String get sortByOperator => 'Sort by operator';

  @override
  String get clearHistoryConfirm => 'Clear history?';

  @override
  String get clearLabel => 'Clear';

  @override
  String get deleteEntryConfirm => 'Delete entry?';

  @override
  String get deleteEntryWarning =>
      'Are you sure you want to delete this history line?';

  @override
  String historyDate(String date) {
    return 'Date: $date';
  }

  @override
  String historyCode(String code) {
    return 'Code: $code';
  }

  @override
  String get profile => 'Profile';

  @override
  String get editProfileInfo => 'Edit information';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get myOperators => 'My Operators';

  @override
  String get statistics => 'Statistics';

  @override
  String get configuredOperations => 'Configured operations';

  @override
  String get scanMerchantCode => 'Scan merchant code';

  @override
  String get placeQrCodeInFrame => 'Place QR code in frame';

  @override
  String get optionalLabel => 'Optional';

  @override
  String get variablesLabel =>
      'Variables (comma-separated, e.g. contact, amount)';

  @override
  String get recentOperations => 'Quick actions';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get incomeEntries => 'Income';

  @override
  String get incomeCategories => 'Income Categories';

  @override
  String get addIncomeCategory => 'Add an income category';

  @override
  String get debtsAndReceivables => 'Debts & Receivables';

  @override
  String get debts => 'Debts';

  @override
  String get receivables => 'Receivables';

  @override
  String get totalDebts => 'Total Debts';

  @override
  String get totalReceivables => 'Total Receivables';

  @override
  String get debtTag => 'Contact / Holder';

  @override
  String get addDebtTag => 'New contact';

  @override
  String get debtBalance => 'Balance';

  @override
  String get recentDebtOperations => 'Recent operations';

  @override
  String get noDebtTags => 'No contact defined';

  @override
  String get deleteDebtConfirm => 'Delete this contact and all its operations?';

  @override
  String get linkToCashFlow => 'Link to an account';

  @override
  String get linkToCashFlowDescription =>
      'Impacts the account balance (income or expense).';

  @override
  String get addDebtOperation => 'Add a debt';

  @override
  String get confirm => 'Confirm';

  @override
  String get filterActiveDebts => 'Active';

  @override
  String get filterOnlyDebts => 'Debts';

  @override
  String get filterOnlyReceivables => 'Receivables';

  @override
  String get filterSettled => 'Settled';

  @override
  String get themeColor => 'Theme Color';

  @override
  String get saveAsExpense => 'Save as an expense';

  @override
  String get onboardingWelcome => 'Welcome to FIMUS';

  @override
  String get onboardingStep1 => 'Choose your language';

  @override
  String get onboardingStep2 => 'Select your country';

  @override
  String get onboardingStep3 => 'Choose your profile';

  @override
  String get onboardingStep4 => 'Enable notifications';

  @override
  String get onboardingNotificationExplanation =>
      'If you share an expense account or a debt with a contact, notifications will be very useful';

  @override
  String get onboardingEnableNotifications => 'Allow notifications';

  @override
  String get onboardingNotificationsEnabled => 'Notifications allowed';

  @override
  String get onboardingSkip => 'Later';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingFinish => 'Get Started';

  @override
  String get onboardingNotifHeader => 'Stay informed in real time';

  @override
  String get onboardingNotifSub =>
      'Never miss a repayment, account update, or transaction alert.';

  @override
  String get onboardingNotifBenefit1Title => 'Debt & due date reminders';

  @override
  String get onboardingNotifBenefit1Desc =>
      'Get automatic reminders before your payment deadline.';

  @override
  String get onboardingNotifBenefit2Title => 'Shared account activity';

  @override
  String get onboardingNotifBenefit2Desc =>
      'Get notified whenever a contact updates a shared expense.';

  @override
  String get onboardingNotifBenefit3Title => 'Security & USSD updates';

  @override
  String get onboardingNotifBenefit3Desc =>
      'Maintain full control over your transaction validations.';

  @override
  String get home => 'Home';

  @override
  String get addIncomeAction => '+ Income';

  @override
  String get addBorrowAction => '+ Borrow';

  @override
  String get addAccountAction => '+ Account';

  @override
  String get addExpenseAction => '+ Expense';

  @override
  String get addLendAction => '+ Lend';

  @override
  String get noContactSaved => 'No contact saved';

  @override
  String get addContactsExplanation =>
      'Add contacts to share accounts and manage shared debts.';

  @override
  String pseudoTag(String code) {
    return 'Username: $code';
  }

  @override
  String get deleteContact => 'Delete contact';

  @override
  String deleteContactConfirm(String name) {
    return 'Are you sure you want to delete $name from your contacts?';
  }

  @override
  String contactHasActiveDebts(String contact) {
    return 'You have active debts with $contact';
  }

  @override
  String createdBy(String name) {
    return 'By $name';
  }

  @override
  String get contactDeleted => 'Contact deleted';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String shareAccount(String name) {
    return 'Share \"$name\"';
  }

  @override
  String accountMembers(String name) {
    return 'Members of \"$name\"';
  }

  @override
  String get currentMembers => 'Current members:';

  @override
  String get unknown => 'Unknown';

  @override
  String get shareWithContact => 'Share with a contact:';

  @override
  String get noContactToShare =>
      'You have no contacts. Add contacts in your profile to share an account.';

  @override
  String get sharingInProgress => 'Sharing in progress...';

  @override
  String accountSharedSuccess(String name) {
    return 'Account shared with $name!';
  }

  @override
  String get shareImpossible =>
      'Sharing impossible. Check your internet connection.';

  @override
  String get close => 'Close';

  @override
  String get share => 'Share';

  @override
  String get unknownAccount => 'Unknown account';

  @override
  String get accountNotFound => 'Account not found';

  @override
  String get untitled => 'Untitled';

  @override
  String get tooltipShareAccount => 'Share account';

  @override
  String get tooltipEditAccount => 'Edit account';

  @override
  String get tooltipDeleteAccount => 'Delete account';

  @override
  String get tooltipViewMembers => 'View members';

  @override
  String get accountBalance => 'Account balance';

  @override
  String get sharedAccountBadge => 'Shared';

  @override
  String sharedByBadge(String name) {
    return 'Shared by $name';
  }

  @override
  String get noOperationOnAccount => 'No operations on this account';

  @override
  String get newContact => 'New contact';

  @override
  String installmentTitle(String current, String total) {
    return 'Installment $current/$total';
  }

  @override
  String get debtRepayment => 'Debt repayment';

  @override
  String get collectReceivable => 'Collect receivable';

  @override
  String get newReceivable => 'New receivable';

  @override
  String get newDebt => 'New debt';

  @override
  String get collectMoney => 'Collect (Money in)';

  @override
  String get repayMoney => 'Repay (Money out)';

  @override
  String get receivableToCollect => 'Receivable (To be collected)';

  @override
  String get debtToRepay => 'Debt (To be repaid)';

  @override
  String get interestDebtSimulator => 'Interest-bearing debt (Simulator)';

  @override
  String get interestDebtSubtitle =>
      'Calculate and schedule repayment installments automatically';

  @override
  String get creditDetails => 'Credit details';

  @override
  String get interestRate => 'Interest rate';

  @override
  String get periodicity => 'Periodicity';

  @override
  String get annual => 'Annual';

  @override
  String get monthly => 'Monthly';

  @override
  String get weekly => 'Weekly';

  @override
  String get daily => 'Daily';

  @override
  String get duration => 'Duration';

  @override
  String get unit => 'Unit';

  @override
  String get months => 'Months';

  @override
  String get years => 'Years';

  @override
  String get repaymentFrequency => 'Repayment frequency';

  @override
  String get amountPerInstallment => 'Amount per installment';

  @override
  String get concernedAccount => 'Account concerned *';

  @override
  String get selectAccount => 'Select an account';

  @override
  String get addComment => 'Add a comment';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String get variableAmount => 'Amount';

  @override
  String get variableNumber => 'Number';

  @override
  String get variableMerchantCode => 'Merchant Code';

  @override
  String get noTransaction => 'No transactions';

  @override
  String get expectedDueDate => 'Expected due date';

  @override
  String get memo => 'Memo';

  @override
  String createdByName(String name) {
    return 'Created by $name';
  }

  @override
  String get borrowAction => 'Borrowing';

  @override
  String get borrowSubtitle => 'Record a debt you contracted';

  @override
  String get lendAction => 'Lending';

  @override
  String get lendSubtitle => 'Money you will collect';

  @override
  String get repaymentAction => 'Repayment';

  @override
  String get noDebtOrReceivableRecorded =>
      'No debt or receivable recorded at the moment.';

  @override
  String get toRepay => 'To repay';

  @override
  String get totalToCollect => 'Total to collect';

  @override
  String get noRecentOperation => 'No recent operations';

  @override
  String get rejectDebt => 'Reject debt';

  @override
  String get rejectDebtConfirm =>
      'Are you sure you want to delete this debt? This action is irreversible and will remove your name from this operation.';

  @override
  String get forgotPin => 'Forgot PIN?';

  @override
  String get forgotPinConfirm =>
      'To unlock the app without your PIN, you must log out. All unsynced data will be kept locally.';

  @override
  String get logout => 'Log out';

  @override
  String get setPin => 'Set a PIN';

  @override
  String get confirmPin => 'Confirm PIN';

  @override
  String get verifyPin => 'PIN verification';

  @override
  String get useBiometrics => 'Use Fingerprint / Face ID';

  @override
  String get username => 'Username';

  @override
  String get pleaseEnterUsername => 'Please enter a username';

  @override
  String get pleaseFillAllFields => 'Please fill in all fields';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotPasswordInstruction =>
      'Enter your email address to receive a new password.';

  @override
  String get email => 'Email';

  @override
  String get emailOrUsername => 'Email or username';

  @override
  String get password => 'Password';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get noNotifications => 'No notifications.';

  @override
  String get notificationFallback => 'New notification';

  @override
  String get notifications => 'Notifications';

  @override
  String get officialLanguage => 'Official language';

  @override
  String get defaultLanguage => 'Default language';

  @override
  String get individualProfile => 'Individual';

  @override
  String get personalManagement => 'Personal management';

  @override
  String get mobileAgentProfile => 'Mobile Agent';

  @override
  String get kioskFleetProfile => 'Kiosk & Fleet';

  @override
  String get editUsername => 'Edit username';

  @override
  String get editUsernameNotice =>
      'Your username must be unique. If successfully updated, your contacts will be notified.';

  @override
  String get newUsername => 'New username';

  @override
  String get usernameUpdatedSuccess => 'Username updated successfully!';

  @override
  String get newPinCode => 'New PIN code';

  @override
  String get confirmPinCode => 'Confirm PIN code';

  @override
  String get pinLockActivated => 'PIN lock activated successfully';

  @override
  String get activate => 'Activate';

  @override
  String get currentPinCode => 'Current PIN code';

  @override
  String get pinLockDisabled => 'PIN lock disabled';

  @override
  String get incorrectPinCode => 'Incorrect PIN code';

  @override
  String get disable => 'Disable';

  @override
  String get createAccount => 'Create an account';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get welcome => 'Welcome';

  @override
  String get login => 'Log in';

  @override
  String get addAccountTitle => 'Add an account';

  @override
  String get accountNameLabel => 'Account name';

  @override
  String get accountColor => 'Account color';

  @override
  String get pleaseEnterName => 'Please enter a name';

  @override
  String get addContactTitle => 'Add a contact';

  @override
  String get userCodeLabel => 'User code (e.g. USR-12345)';

  @override
  String get search => 'Search';

  @override
  String get addToContacts => 'Add to contacts';

  @override
  String get contactNotFound => 'Contact not found';

  @override
  String get searchCountryHint => 'Search country...';

  @override
  String get noCountryFound => 'No country found';

  @override
  String get catExpenseFood => 'Food';

  @override
  String get catExpenseTransport => 'Transport';

  @override
  String get catExpenseLeisure => 'Leisure';

  @override
  String get catExpenseHealth => 'Health';

  @override
  String get catExpenseBills => 'Bills';

  @override
  String get catExpenseOther => 'Other';

  @override
  String get catIncomeSalary => 'Salary';

  @override
  String get catIncomePension => 'Pension';

  @override
  String get catIncomeFees => 'Fees';

  @override
  String get catIncomeProfits => 'Profits';

  @override
  String get catIncomeDividends => 'Dividends';

  @override
  String get catIncomeSale => 'Sale Of Goods';

  @override
  String get catIncomeDonations => 'Donations';

  @override
  String get catIncomeInheritance => 'Inheritance';

  @override
  String get catIncomeOther => 'Other';

  @override
  String get catUssdDeposit => 'Deposit';

  @override
  String get catUssdWithdrawal => 'Withdrawal';

  @override
  String get catUssdTransfer => 'Transfer';

  @override
  String get catUssdMerchantPayment => 'Merchant Payment';

  @override
  String get catUssdCredit => 'Airtime';

  @override
  String get catUssdBalance => 'Balance';

  @override
  String get catUssdInternet => 'Internet';

  @override
  String get catUssdOther => 'Other';

  @override
  String get ussdActionCashIn => 'Cash-In';

  @override
  String get ussdActionCashOutAgent => 'Cash-Out (Agent)';

  @override
  String get ussdActionCashOutClient => 'Cash-Out (Client code)';

  @override
  String get ussdActionTransfer => 'Money Transfer';

  @override
  String get ussdActionMerchant => 'Merchant Payment';

  @override
  String get ussdActionBalanceAgent => 'Agent/UV Balance';

  @override
  String get ussdActionCredit => 'Buy Airtime';

  @override
  String get ussdActionCashInAgent => 'Cash Deposit (Cash-In Agent)';

  @override
  String get ussdActionBalanceFleet => 'Fleet/Agent Account Balance';

  @override
  String get ussdActionInternet => 'Buy Internet Bundle';

  @override
  String get resetPasswordBtn => 'RESET';

  @override
  String get finalizeRegistration => 'Finalize Registration';

  @override
  String get finalizeRegistrationDesc =>
      'To complete the creation of your account via Google, please provide the information below.';

  @override
  String get uniqueIdentifierDesc => 'This is your unique identifier on FIMUS';

  @override
  String get accountType => 'Account Type';

  @override
  String get noAccountYet => 'Don\'t have an account yet? ';

  @override
  String get registerNow => 'Register';

  @override
  String get fullName => 'Full name';

  @override
  String get pleaseSelectCountry => 'Please select your country';

  @override
  String get min8Chars => 'Minimum 8 characters';

  @override
  String get professionalProfile => 'Professional';

  @override
  String get enableLock => 'Enable Lock';

  @override
  String get enableLockDesc => 'Set a 4-digit PIN to secure access.';

  @override
  String get disableLock => 'Disable Lock';

  @override
  String get disableLockDesc =>
      'Please enter your current PIN to disable the lock.';

  @override
  String get changePinCode => 'Change PIN Code';

  @override
  String get changePinCodeDesc => 'Change your 4-digit PIN';

  @override
  String get pinCodeChangedSuccess => 'PIN code changed successfully';

  @override
  String get incorrectCurrentPinCode => 'Incorrect current PIN code';

  @override
  String get myUniqueId => 'My Unique ID';

  @override
  String get uniqueIdCopied => 'Unique ID copied!';

  @override
  String get myContacts => 'My Contacts';

  @override
  String get manageContactsDesc =>
      'Manage your contacts for sharing accounts and debts';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncNowDesc => 'Pushes your local data to the cloud';

  @override
  String get lockApp => 'Lock App';

  @override
  String get lockAppDesc => 'Secure access with a PIN code';

  @override
  String get unlockWithBiometrics => 'Unlock with biometrics';

  @override
  String get errorMarkNotifRead =>
      'Error: unable to mark notification as read.';

  @override
  String get errorMarkAllNotifRead =>
      'Error: unable to mark notifications as read.';

  @override
  String get completeProfileTitle => 'Complete your profile';

  @override
  String get completeProfileSubtitle => 'A few more details are required';

  @override
  String get countryOfResidence => 'Country of residence';

  @override
  String get selectCountry => 'Select a country';

  @override
  String get pseudo => 'Pseudo';

  @override
  String get pseudoExample => 'Ex: mark123';

  @override
  String get countryRequired => 'Please select a country';

  @override
  String get finish => 'Finish';

  @override
  String get pseudoRequired => 'Please enter a pseudo';

  @override
  String get pseudoLength => 'The pseudo must be between 3 and 15 characters';

  @override
  String get pseudoFormat =>
      'Only letters, numbers, dashes, and underscores are allowed';

  @override
  String get tooManyRequests => 'Too many attempts. Please try again later.';

  @override
  String tooManyRequestsRetry(String seconds) {
    return 'Too many attempts. Please try again in $seconds seconds.';
  }

  @override
  String get deleteUserAccount => 'Delete my account';

  @override
  String get deleteUserAccountConfirm => 'Delete account';

  @override
  String get deleteUserAccountWarning =>
      'Are you sure you want to permanently delete your FIMUS account? This action is irreversible and will delete all your data from the server.';

  @override
  String get accountDeletedSuccess =>
      'Your account has been deleted successfully.';

  @override
  String get tabOperations => 'Transactions';

  @override
  String get tabBreakdown => 'Overview & Poles';

  @override
  String get spendingByPole => 'Spending by pole';

  @override
  String get spendingByMember => 'Spending by member';

  @override
  String get familyContributions => 'Contributions';

  @override
  String get shareWithContacts => 'Share with contacts';

  @override
  String get selectContacts => 'Select contacts';

  @override
  String get noContactsSelected => 'No contacts selected';

  @override
  String get noContactFound => 'No contact found';

  @override
  String get linkedContacts => 'Linked contacts';

  @override
  String get accountSharedSuccessMultiple => 'Account shared successfully!';

  @override
  String get filterAll => 'All poles';

  @override
  String get periodMonth => 'This month';

  @override
  String get periodLastMonth => 'Last month';

  @override
  String get period30Days => 'Last 30 days';

  @override
  String get periodYear => 'This year';

  @override
  String get periodCustom => 'Custom';

  @override
  String get totalExpenses => 'Total expenses';

  @override
  String get totalIncomes => 'Total incomes';

  @override
  String get netBalance => 'Net balance';

  @override
  String get noExpenseInPeriod => 'No expenses in this period';

  @override
  String get addContactsToShare => 'Add contacts';

  @override
  String selectedContactsCount(int count) {
    return '$count contact(s) selected';
  }

  @override
  String get profileTypeSection => 'Usage Profile';

  @override
  String get currentProfileType => 'Current profile type';

  @override
  String get switchToProfessional => 'Switch to Professional profile';

  @override
  String get switchToPersonal => 'Switch to Personal profile';

  @override
  String get profileTypePermanent => 'Permanent profile';

  @override
  String get profileTypeAlreadyChanged =>
      'You have already changed your profile. This choice is now irreversible.';

  @override
  String get profileTypeOneTimeHint => 'One-time change allowed';

  @override
  String get profileChangeTitle => 'Change profile?';

  @override
  String get profileChangeToProfessionalDesc =>
      'By switching to the Professional profile, you will gain access to Merchant / Agent USSD codes, cash register tools and commercial transactions.';

  @override
  String get profileChangeToPersonalDesc =>
      'By switching to the Personal profile, your interface will be simplified and focused on your personal finances and expenses.';

  @override
  String get profileChangeWarning =>
      'Warning: this action is permanent. You will not be able to revert to your previous profile after confirmation.';

  @override
  String get confirmProfileChange => 'Confirm change';

  @override
  String get profileChangeSuccess => 'Profile changed successfully';

  @override
  String get profileChangeError => 'Error changing profile';

  @override
  String get announcements => 'Announcements';

  @override
  String get enableNotificationsPrompt =>
      'Enable notifications to stay updated.';

  @override
  String get batteryOptimizationPrompt =>
      'To receive reminders on time, allow FIMUS to ignore battery optimization.';

  @override
  String get onboardingNotificationsDenied =>
      'Notifications not allowed. You can enable them later in settings.';

  @override
  String get notifyDebtsPref => 'Debts and repayments';

  @override
  String get notifyDebtsPrefDesc =>
      'Alerts when a shared debt is created, updated, or declined.';

  @override
  String get notifyContactsPref => 'Contacts';

  @override
  String get notifyContactsPrefDesc =>
      'Alerts when someone adds you to their contacts.';

  @override
  String get notifyJointAccountsPref => 'Joint accounts';

  @override
  String get notifyJointAccountsPrefDesc =>
      'Alerts when you are invited to a shared account.';

  @override
  String get confirmAndRegister => 'CONFIRM AND REGISTER';

  @override
  String get suggestionsLabel => 'Suggestions:';

  @override
  String get unnamedContact => 'A contact';

  @override
  String get debtDueNotifTitleDebt => '⏰ Due date reminder: Debt';

  @override
  String get debtDueNotifTitleReceivable => '⏰ Due date reminder: Receivable';

  @override
  String debtDueNotifBodyDebt(String amount, String currency, String name) {
    return 'Your debt of $amount $currency to $name is due today.';
  }

  @override
  String debtDueNotifBodyReceivable(
    String amount,
    String currency,
    String name,
  ) {
    return 'The repayment of $amount $currency by $name is due today.';
  }

  @override
  String get scheduledExpenseNotifTitle => '⏰ Scheduled expense';

  @override
  String scheduledExpenseNotifBody(
    String title,
    String amount,
    String currency,
    String time,
  ) {
    return '\"$title\" · $amount $currency — due at $time. Tap to confirm, edit, or cancel.';
  }

  @override
  String get scheduledConfirmAction => 'Confirm';

  @override
  String get scheduledCancelAction => 'Cancel';

  @override
  String get scheduledExpense => 'Scheduled expense';

  @override
  String get scheduledLabel => 'Scheduled';

  @override
  String get addScheduledExpense => 'Add scheduled expense';

  @override
  String get editScheduledExpense => 'Edit scheduled expense';

  @override
  String get scheduledExpenses => 'Scheduled expenses';

  @override
  String get dateAndTime => 'Date and time';

  @override
  String get confirmExpense => 'Confirm expense';

  @override
  String get modify => 'Modify';

  @override
  String get cancelScheduledExpense => 'Cancel scheduled expense';

  @override
  String get cancelScheduledExpenseTitle => 'Cancel this scheduled expense?';

  @override
  String get cancelScheduledExpenseBody =>
      'The scheduled expense will be deleted and you will no longer be notified.';

  @override
  String get futureDateRequired => 'Date and time must be in the future.';

  @override
  String get scheduledExpensesEmpty => 'No scheduled expenses yet.';

  @override
  String get saveSchedule => 'Save schedule';

  @override
  String get scheduleSaved =>
      'Scheduled expense saved. You will be notified when it is due.';

  @override
  String get scheduleUpdated => 'Schedule updated.';

  @override
  String get scheduledExpenseConfirmed => 'Expense confirmed ✅';

  @override
  String get scheduledExpenseCancelled => 'Scheduled expense cancelled';

  @override
  String get confirmNow => 'Confirm now';

  @override
  String upcomingScheduledExpenses(int count) {
    return '$count scheduled expense(s)';
  }

  @override
  String scheduledOn(String date) {
    return 'Scheduled for: $date';
  }

  @override
  String scheduledTodayAt(String time) {
    return 'today at $time';
  }

  @override
  String scheduledInDays(int days) {
    return 'in $days day(s)';
  }

  @override
  String get editExpense => 'Edit expense';

  @override
  String get editIncome => 'Edit income';

  @override
  String get operationOptions => 'Transaction options';

  @override
  String get detailsTitle => 'Transaction details';

  @override
  String get typeLabel => 'Type';

  @override
  String get operationDate => 'Transaction date';

  @override
  String get recordedDate => 'Recorded date';

  @override
  String get recordedBy => 'Recorded by';

  @override
  String get linkedAccount => 'Linked account';

  @override
  String get noteLabel => 'Note';

  @override
  String get noNote => 'No note';

  @override
  String get me => 'Me';

  @override
  String get status => 'Status';

  @override
  String get dueDateLabel => 'Due date';

  @override
  String get debtTagLabel => 'Related person';

  @override
  String get debtStatusPending => 'Pending';

  @override
  String get debtStatusAccepted => 'Accepted';

  @override
  String sharedAccountOperationBy(String name) {
    return 'Operation recorded on this shared account by $name';
  }

  @override
  String get myAccount => 'My Account';

  @override
  String get user => 'User';

  @override
  String get myPseudo => 'My Pseudo';

  @override
  String get notDefined => 'Not defined';

  @override
  String get pseudoCopied => 'Pseudo copied!';

  @override
  String syncComplete(int pushed, int pulled) {
    return 'Sync complete — $pushed pushed, $pulled pulled';
  }

  @override
  String syncError(String message) {
    return 'Error: $message';
  }

  @override
  String get logoutTitle => 'Log out';

  @override
  String get logoutConfirmBody =>
      'Are you sure you want to log out? Your local data will be preserved.';

  @override
  String get loginToSync => 'Log in to sync your data to the cloud.';

  @override
  String get accessSecurity => 'Access Security';

  @override
  String get fingerprintFaceId => 'Fingerprint / Face ID';

  @override
  String get enter4Digits => 'Enter 4 digits';

  @override
  String get pinCodesDoNotMatch => 'PIN codes do not match';

  @override
  String get pinRequired => 'PIN code required';

  @override
  String get environmentDevMode => 'Environment & Dev Mode';

  @override
  String get devModeLocalDb => 'Developer Mode (Local DB)';

  @override
  String get productionMode => 'Production Mode (PlayStore)';

  @override
  String connectedToLocalDb(String url) {
    return 'Connected to local database: $url';
  }

  @override
  String get connectedToOnlineServer =>
      'Connected to the secure online server (PlayStore)';

  @override
  String get enableDevModeTitle => 'Enable Dev Mode?';

  @override
  String get enableDevModeBody =>
      'In Dev Mode, the app connects to your local database (local Laravel) and isolates data in monitrack_dev.db.\n\nYou can switch back to Production Mode at any time before PlayStore publication.';

  @override
  String get enableDevModeBtn => 'Enable Dev Mode';

  @override
  String localDbInfo(String db, String url) {
    return 'Local database active: $db\nAPI URL: $url';
  }

  @override
  String get localEnvType => 'Local environment type:';

  @override
  String get hostVhost => 'Host fimus.local (Recommended)';

  @override
  String get hostEmulator => 'Android Emulator (10.0.2.2)';

  @override
  String get hostWeb => 'Localhost / Web';

  @override
  String get hostCustom => 'Custom IP / URL';

  @override
  String get localApiUrlLabel => 'Local API URL (Laravel Server)';

  @override
  String get localApiUrlHint =>
      'http://fimus.local/api or http://192.168.1.50:8000/api';

  @override
  String get localApiUrlHelper =>
      'Enter your local server address (e.g. http://fimus.local/api or WiFi IP).';

  @override
  String get testConnection => 'Test connection';

  @override
  String get devHostApply => 'Apply';

  @override
  String get resetToLaunchProfile => 'Back to launch profile';

  @override
  String connectionTestOk(int ms) {
    return 'Connection successful ($ms ms)';
  }

  @override
  String connectionTestHttpStatus(int code) {
    return 'Server responded with code $code';
  }

  @override
  String get connectionTestTimeout =>
      'Timed out (> 4 s). Check the URL or the server.';

  @override
  String get connectionTestRefused =>
      'Connection refused. Is the local server running?';

  @override
  String connectionTestError(String error) {
    return 'Error: $error';
  }

  @override
  String get purgeTestDbTitle => 'Purge the local test database?';

  @override
  String get purgeTestDbBody =>
      'This action deletes the test data from monitrack_dev.db. Your production database will not be affected.';

  @override
  String get purge => 'Purge';

  @override
  String get purgeTests => 'Purge tests';

  @override
  String get backToProduction => 'Back to Production';

  @override
  String get allCategoriesSelected => 'Categories';

  @override
  String categoriesSelectedCount(int count) {
    return '$count categories';
  }

  @override
  String get filterByCategory => 'Filter by category';

  @override
  String get accountsDesc => 'Accounts signed in on this device';

  @override
  String accountsCount(int count) {
    return '$count accounts signed in';
  }

  @override
  String get addAccountSubtitle =>
      'Sign in to another MoniTrack account on this device';

  @override
  String get activeAccount => 'Active';

  @override
  String deviceAccountLimit(int max) {
    return 'You can connect up to $max accounts on this device. Sign out of one to add another.';
  }

  @override
  String createCategory(String name) {
    return 'Create « $name »';
  }

  @override
  String get notificationSettingsTitle => 'Notifications';

  @override
  String get notificationSettingsSubtitle =>
      'Permissions, categories and quiet hours';

  @override
  String get notificationPermissionSection => 'System permission';

  @override
  String get notificationPermissionGranted => 'Notifications allowed';

  @override
  String get notificationPermissionGrantedDesc =>
      'FIMUS can alert you in real time.';

  @override
  String get notificationPermissionDenied => 'Notifications blocked';

  @override
  String get notificationPermissionDeniedDesc =>
      'Without permission, due-date reminders and shared debt alerts will not be displayed.';

  @override
  String get notificationPermissionUnknown => 'Permission not checked';

  @override
  String get notificationPermissionUnknownDesc =>
      'Check the permission status to receive alerts.';

  @override
  String get notificationPermissionCheck => 'Check';

  @override
  String get notificationPermissionOpenSettings => 'Open settings';

  @override
  String get notificationPermissionSettingsHint =>
      'The system will not ask again. Enable notifications from the app settings.';

  @override
  String get notificationPermissionRationaleTitle => 'Enable notifications?';

  @override
  String get notificationPermissionRationaleBody =>
      'FIMUS notifies you when a debt is due, when someone adds you to a shared account and before a scheduled expense. No promotional notification is sent without your consent.';

  @override
  String get notificationPermissionRationaleConfirm => 'Allow';

  @override
  String get notificationPermissionRationaleDismiss => 'Later';

  @override
  String get notificationCategoriesSection => 'Categories';

  @override
  String get notifyScheduledExpensesPref => 'Scheduled expenses';

  @override
  String get notifyScheduledExpensesPrefDesc =>
      'Reminders before a recurring expense is charged.';

  @override
  String get reminderScheduleSection => 'Reminders';

  @override
  String get reminderHourTitle => 'Reminder time';

  @override
  String get reminderHourDesc => 'Time at which due-date reminders are sent.';

  @override
  String get quietHoursTitle => 'Quiet hours';

  @override
  String get quietHoursDesc => 'Pause notifications during a time range.';

  @override
  String get quietHoursStartLabel => 'Start';

  @override
  String get quietHoursEndLabel => 'End';

  @override
  String get quietHoursOvernightHint => 'The range continues past midnight.';

  @override
  String get exactAlarmsTitle => 'Exact alarms';

  @override
  String get exactAlarmsDesc =>
      'Required to fire reminders at the exact time. Without them, Android may delay them by several hours.';

  @override
  String get exactAlarmsGranted => 'Allowed';

  @override
  String get exactAlarmsMissing => 'Not allowed';

  @override
  String get exactAlarmsAllow => 'Allow';

  @override
  String get notificationPreferencesLoadError =>
      'Could not load your notification preferences.';

  @override
  String get notificationPreferencesSaveError =>
      'Could not save the change. It has been reverted.';

  @override
  String get notificationPreferencesOfflineHint =>
      'Values stored on this device, shown offline.';

  @override
  String get offlineBanner => 'Offline · local data';

  @override
  String offlineBannerWithDate(String date) {
    return 'Offline · data from $date';
  }

  @override
  String get notifChannelDebtsName => 'Debts and repayments';

  @override
  String get notifChannelDebtsDesc =>
      'Shared debts, repayments and due date reminders.';

  @override
  String get notifChannelScheduledExpensesName => 'Scheduled expenses';

  @override
  String get notifChannelScheduledExpensesDesc =>
      'Reminders for the expenses you scheduled.';

  @override
  String get notifChannelContactsName => 'Contacts';

  @override
  String get notifChannelContactsDesc =>
      'Alerts when someone adds you to their contacts.';

  @override
  String get notifChannelJointAccountsName => 'Joint accounts';

  @override
  String get notifChannelJointAccountsDesc =>
      'Invitations and activity on shared accounts.';

  @override
  String get notifChannelGeneralName => 'General';

  @override
  String get notifChannelGeneralDesc => 'FIMUS service notifications.';

  @override
  String get notifChannelAnnouncementsName => 'Announcements';

  @override
  String get notifChannelAnnouncementsDesc =>
      'FIMUS news, tips and offers. Silent.';

  @override
  String get loadMore => 'Load more';

  @override
  String get notificationFilterContacts => 'Contacts';

  @override
  String get notificationFilterScheduled => 'Scheduled';

  @override
  String get notificationSectionEarlier => 'Earlier';

  @override
  String get notificationUnreadBadge => 'Unread';

  @override
  String get notificationReadBadge => 'Read';

  @override
  String get notificationTimeJustNow => 'Just now';

  @override
  String notificationTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '$count min ago',
    );
    return '$_temp0';
  }

  @override
  String notificationTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h ago',
      one: '$count h ago',
    );
    return '$_temp0';
  }

  @override
  String get notificationDeleted => 'Notification deleted';

  @override
  String get undoAction => 'Undo';

  @override
  String get clearSelectionTooltip => 'Exit selection';

  @override
  String notificationsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '$count selected',
    );
    return '$_temp0';
  }

  @override
  String get notificationsEmptyForFilter =>
      'No notifications in this category.';

  @override
  String get notificationsShowAllFilters => 'Show all notifications';

  @override
  String get displayMode => 'Display mode';

  @override
  String get displayModeSubtitle => 'Choose how the app looks';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get notifChannelAlertsName => 'Finance alerts';

  @override
  String get notifChannelAlertsDesc =>
      'Budget reached, low balance, data waiting to be sent';

  @override
  String get alertBudgetWarningTitle => 'Budget almost reached';

  @override
  String alertBudgetWarningBody(
    String category,
    int percent,
    String spent,
    String budget,
    String currency,
  ) {
    return '$category: $percent% of the budget used ($spent / $budget $currency) this month.';
  }

  @override
  String get alertBudgetReachedTitle => 'Budget exceeded';

  @override
  String alertBudgetReachedBody(
    String category,
    int percent,
    String spent,
    String budget,
    String currency,
  ) {
    return '$category: $percent% of the budget used ($spent / $budget $currency) this month.';
  }

  @override
  String get alertLowBalanceTitle => 'Low balance';

  @override
  String alertLowBalanceBody(
    String account,
    String balance,
    String threshold,
    String currency,
  ) {
    return '$account: $balance $currency, below your $threshold $currency threshold.';
  }

  @override
  String get alertUnsyncedTitle => 'Unsynced data';

  @override
  String alertUnsyncedBody(int count, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count entries have been waiting to be sent for $hours h. Sync to avoid losing them.',
      one:
          '1 entry has been waiting to be sent for $hours h. Sync to avoid losing it.',
    );
    return '$_temp0';
  }

  @override
  String get localAlertsSection => 'Custom alerts';

  @override
  String get alertsLocalOnlyNotice =>
      'These settings are stored on this device only: they do not follow your account to another phone.';

  @override
  String get alertBudgetSwitchTitle => 'Budget threshold';

  @override
  String get alertBudgetSwitchDesc =>
      'Warn you at 80% and then 100% of a category monthly budget';

  @override
  String get alertLowBalanceSwitchTitle => 'Low balance';

  @override
  String get alertLowBalanceSwitchDesc =>
      'Warn you when an account drops below its threshold';

  @override
  String get alertUnsyncedSwitchTitle => 'Unsynced data';

  @override
  String get alertUnsyncedSwitchDesc =>
      'Warn you when entries have been waiting too long to be sent';

  @override
  String get alertBudgetsManageTitle => 'Monthly budgets by category';

  @override
  String get alertThresholdsManageTitle => 'Balance thresholds by account';

  @override
  String get alertTrackedNone => 'Nothing tracked yet';

  @override
  String alertBudgetsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories tracked',
      one: '1 category tracked',
    );
    return '$_temp0';
  }

  @override
  String alertThresholdsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts tracked',
      one: '1 account tracked',
    );
    return '$_temp0';
  }

  @override
  String get alertUnsyncedDelayTitle => 'Delay before alerting';

  @override
  String alertUnsyncedDelayValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get alertBudgetsDialogTitle => 'Monthly budgets';

  @override
  String get alertThresholdsDialogTitle => 'Low balance thresholds';

  @override
  String get alertBudgetFieldLabel => 'Monthly budget';

  @override
  String get alertThresholdFieldLabel => 'Alert threshold';

  @override
  String get alertValueNotSet => 'Not set';

  @override
  String get alertNoCategories => 'No expense category available.';

  @override
  String get alertNoAccounts => 'No account available.';

  @override
  String get alertInvalidAmount => 'Enter a valid amount.';

  @override
  String get alertResetStateTitle => 'Reset alerts already sent';

  @override
  String get alertResetStateDesc =>
      'Allow alerts you already received this month to fire again';

  @override
  String get alertResetStateDone => 'Alerts reset';

  @override
  String get savingInProgress => 'Saving...';

  @override
  String get savedLocallyWillSync =>
      'The entry was saved on your phone. It will sync as soon as your internet connection is back.';

  @override
  String get genericErrorRetry => 'Something went wrong. Please try again.';

  @override
  String get debtOpCollectRepaymentTitle => 'Receive a repayment';

  @override
  String get debtOpRepayDebtTitle => 'Repay a debt';

  @override
  String get debtOpNewBorrowTitle => 'New borrowing (Debt)';

  @override
  String get debtOpNewLoanTitle => 'New loan (Receivable)';

  @override
  String debtOpCollectFromHint(String name) {
    return 'Receive a repayment from $name';
  }

  @override
  String debtOpRepayToHint(String name) {
    return 'Repay the debt owed to $name';
  }

  @override
  String get debtOpSettledSuffix => '(Settled)';

  @override
  String debtOpTotalToRepay(String amount, String currency) {
    return 'Total to repay: $amount $currency';
  }

  @override
  String get receivableInterestSimulator =>
      'Receivable with interest (Simulator)';

  @override
  String get debtOpNoCashFlowImpact =>
      'This entry is for reference only: it affects neither your accounts nor your statistics.';

  @override
  String get debtOpNoLinkableAccount => 'No account available to link to.';

  @override
  String get pleaseChooseAccount => 'Please choose an account';

  @override
  String get debtOpSetDueDate => 'Set a due date';

  @override
  String get debtOpSetDueDateDesc => 'Recommended repayment deadline';

  @override
  String get debtOpDueDatePlanned => 'Planned due date';

  @override
  String get selectDate => 'Select a date';

  @override
  String get frequencyMonthly => 'Monthly';

  @override
  String get frequencyWeekly => 'Weekly';

  @override
  String get frequencyDaily => 'Daily';

  @override
  String get frequencyAnnual => 'Yearly';

  @override
  String get debtBadgeSettled => 'Settled';

  @override
  String get debtBadgeToRepay => 'Debt to repay';

  @override
  String get debtBadgeToCollect => 'Receivable to collect';

  @override
  String get filterLabel => 'Filter:';

  @override
  String get validate => 'Confirm';

  @override
  String get debtKind => 'Debt';

  @override
  String get receivableKind => 'Receivable';

  @override
  String get createdByMe => 'Me';

  @override
  String get createdByMember => 'Member';

  @override
  String get debtNewOperationTitle => 'New debt entry';

  @override
  String get debtSelectTitle => 'Select a debt';

  @override
  String get someone => 'Someone';

  @override
  String debtPendingInvitation(String name, String title) {
    return '$name has linked you to a debt: $title';
  }

  @override
  String debtDueDateOverdue(String date) {
    return 'Overdue since $date';
  }

  @override
  String debtDueDatePlanned(String date) {
    return 'Due on $date';
  }

  @override
  String debtDueDateValue(String date) {
    return 'Due: $date';
  }

  @override
  String get selectPeriod => 'Select a period';

  @override
  String get selectPeriodMax6Months => 'Select a period (max 6 months)';

  @override
  String operationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '$count entry',
    );
    return '$_temp0';
  }

  @override
  String get exampleLabel => 'Example:';

  @override
  String get ussdQuickInsertChips => 'Quick insert chips:';

  @override
  String get ussdPreviewTitle => 'Preview of the run screen';

  @override
  String ussdPreviewEmptyHint(String first, String second) {
    return 'Enter a USSD code containing variables such as $first or $second to generate the preview.';
  }

  @override
  String get ussdAmountToTransferLabel => 'Amount to transfer';

  @override
  String get productPhotoTitle => 'Product photo';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get deletePhoto => 'Remove photo';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get productUpdated => 'Product updated';

  @override
  String get productSaved => 'Product saved successfully';

  @override
  String get editProductTitle => 'Edit product';

  @override
  String get newProductTitle => 'New product';

  @override
  String get productNameLabel => 'Product name *';

  @override
  String get productNameHint => 'E.g. 25 kg rice bag, Phone…';

  @override
  String get productNameRequired => 'Please enter the product name';

  @override
  String productPriceLabel(String currency) {
    return 'Selling price ($currency) *';
  }

  @override
  String get productPriceRequired => 'Please enter the price';

  @override
  String get productPriceInvalid => 'Invalid price';

  @override
  String get productDescriptionLabel => 'Description (optional)';

  @override
  String get productDescriptionHint => 'Details, size, colour, packaging…';

  @override
  String get updateAction => 'UPDATE';

  @override
  String get saveProductAction => 'SAVE PRODUCT';

  @override
  String get staffUpdated => 'Team member updated';

  @override
  String get staffAdded => 'Team member added successfully';

  @override
  String get editStaffTitle => 'Edit team member';

  @override
  String get newStaffTitle => 'New team member';

  @override
  String get staffNameLabel => 'First & last name *';

  @override
  String get staffNameHint => 'E.g. Amadou Diallo';

  @override
  String get staffNameRequired => 'Please enter the name';

  @override
  String get staffRoleLabel => 'Role / Position';

  @override
  String get staffRoleHint => 'E.g. Accountant, Sales rep, Technician…';

  @override
  String get phoneNumberLabel => 'Phone number';

  @override
  String get staffPhoneHint => 'E.g. +221 77 123 45 67';

  @override
  String get emailAddressLabel => 'Email address';

  @override
  String get staffEmailHint => 'E.g. amadou@company.com';

  @override
  String staffSalaryLabel(String currency) {
    return 'Monthly pay ($currency)';
  }

  @override
  String get addStaffAction => 'ADD TEAM MEMBER';

  @override
  String get deleteProductTitle => 'Delete this product?';

  @override
  String deleteProductConfirm(String name) {
    return 'Do you really want to delete \"$name\"?';
  }

  @override
  String productDeleted(String name) {
    return 'Product \"$name\" deleted';
  }

  @override
  String get searchProductHint => 'Search for a product…';

  @override
  String productsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '$count product',
    );
    return '$_temp0';
  }

  @override
  String get noProductFound => 'No product found';

  @override
  String get emptyCatalog => 'Your catalogue is empty';

  @override
  String get trySearchAgain => 'Try another search.';

  @override
  String get emptyCatalogHint => 'Save your items to handle sales quickly.';

  @override
  String get addFirstProduct => 'Add my first product';

  @override
  String get deleteStaffTitle => 'Remove this team member?';

  @override
  String deleteStaffConfirm(String name) {
    return 'Do you really want to remove \"$name\" from your team?';
  }

  @override
  String staffDeleted(String name) {
    return 'Team member \"$name\" removed';
  }

  @override
  String get searchStaffHint => 'Search for a team member…';

  @override
  String staffCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count team members',
      one: '$count team member',
    );
    return '$_temp0';
  }

  @override
  String get noStaffFound => 'No team member found';

  @override
  String get noStaffRecorded => 'No team member yet';

  @override
  String get emptyStaffHint =>
      'Organise your team, their roles and work contacts.';

  @override
  String get addStaffMember => 'Add a team member';

  @override
  String get googleSignInInterrupted =>
      'Sign-in was interrupted, please try again.';

  @override
  String get googleSignInNoAccount =>
      'No Google account found. Add one or use email and password.';

  @override
  String get googleSignInUnavailable =>
      'Configuration unavailable. Please try again later.';

  @override
  String get googleSignInUpdatePlayServices =>
      'Please update Google Play Services.';

  @override
  String get googleSignInAccountChanged =>
      'Account change detected, please try again.';

  @override
  String get googleSignInGenericError =>
      'Google sign-in failed. Please try again.';

  @override
  String get forgotPasswordSent =>
      'A new password has been sent to your email address. Check your spam folder if it is not in your inbox.';

  @override
  String get loginSubtitle => 'Sign in to manage your finances';

  @override
  String get loginAction => 'SIGN IN';

  @override
  String get orSeparator => 'OR';

  @override
  String get noAccountQuestion => 'Don\'t have an account? ';

  @override
  String get haveAccountQuestion => 'Already have an account? ';

  @override
  String get registerAccountAction => 'CREATE MY ACCOUNT';

  @override
  String get registerSubtitle => 'Create your account in seconds';

  @override
  String get registerSuccessEmailSent =>
      'Account created! Your password has been emailed to you so you won\'t forget it.';

  @override
  String get startAction => 'GET STARTED';

  @override
  String get back => 'Back';

  @override
  String onboardingStepProgress(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingCountryHint =>
      'FIMUS adapts your operators and USSD codes to your location.';

  @override
  String get onboardingProfileTypeHint =>
      'Pick how you will use the app so we can tailor the interface.';

  @override
  String get profileTypePersonal => 'Personal';

  @override
  String get profileTypeSmallBusiness => 'Small shop';

  @override
  String get profileTypeSmallBusinessShort => 'Shop';

  @override
  String get profileTypeSmallBusinessDesc => 'Sales & Products';

  @override
  String get profileTypeCompany => 'Company';

  @override
  String get profileTypeCompanyDesc => 'Services & Team';

  @override
  String get profileTypeKiosk => 'Kiosk';

  @override
  String get profileTypeKioskDesc => 'Money transfer';

  @override
  String get lockTooManyAttemptsReauth =>
      'Too many attempts. Sign in again with your password.';

  @override
  String lockTooManyAttemptsRetryIn(String delay) {
    return 'Too many attempts. Try again in $delay.';
  }

  @override
  String get verifying => 'Checking…';

  @override
  String lockIncorrectPinAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wrong PIN · $count attempts before lockout',
      one: 'Wrong PIN · $count attempt before lockout',
    );
    return '$_temp0';
  }

  @override
  String get enterYourPin => 'Enter your PIN';

  @override
  String get securityTitle => 'Security';

  @override
  String get lockFullReauthBody =>
      'Too many wrong PINs were entered. For your security, sign in again with your password. Your local data is kept.';

  @override
  String get reconnectAction => 'Sign in again';

  @override
  String get lockForgotPinBody =>
      'For security reasons, if you have forgotten your PIN you must sign out and sign in again. Your synced local data will be kept.';

  @override
  String get ussdLoadingCodes => 'Loading USSD codes…';

  @override
  String get ussdNoOperatorAvailable => 'No operator available';

  @override
  String get ussdSelectCountryOrAddOperator =>
      'Select a country or add an operator';

  @override
  String get ussdAddOperatorSubtitle =>
      'Set up a new mobile operator for your USSD codes';

  @override
  String get ussdHiddenBadge => 'Hidden';

  @override
  String get ussdHideOperation => 'Hide this operation';

  @override
  String get ussdShowOperation => 'Show this operation';

  @override
  String get navProducts => 'Products';

  @override
  String get navStaff => 'Team';

  @override
  String get changeProfileAction => 'Change profile';

  @override
  String get profileTypeChooseNew => 'Choose a new profile';

  @override
  String get profileTypeChangeWarningOnce =>
      'Warning: this change can only be made once and is final.';

  @override
  String get profileChangeToSmallBusinessDesc =>
      'Switching to the Small shop profile gives you the product catalogue to record and track the items you sell.';

  @override
  String get profileChangeToCompanyDesc =>
      'Switching to the Company profile gives you the Staff module to manage your team members, roles and work contacts.';

  @override
  String get profileChangeToKioskDesc =>
      'Switching to the Kiosk profile gives you Merchant/Agent USSD codes and Mobile Money cash-handling tools.';

  @override
  String get announcementFallback1 =>
      'Set up your favourite USSD codes to run your transactions in a single tap!';

  @override
  String get announcementFallback2 =>
      'You can now add or remove your own USSD operators with ease.';

  @override
  String get announcementFallback3 =>
      'Budget tracking: follow your daily spending and stay in control thanks to our detailed reports.';

  @override
  String get notifyWeeklyDigestPref => 'Weekly digest';

  @override
  String get notifyWeeklyDigestPrefDesc =>
      'A summary of your spending for the week, sent every Sunday.';

  @override
  String get newLoginConfirmTitle => 'Wasn\'t this you?';

  @override
  String get newLoginConfirmBody =>
      'All other sessions on your account will be signed out. This device will stay signed in.';

  @override
  String newLoginConfirmBodyWithDetails(String details) {
    return 'Login detected: $details.\n\nAll other sessions on your account will be signed out. This device will stay signed in.';
  }

  @override
  String get newLoginConfirmAction => 'This wasn\'t me';

  @override
  String revokeOtherSessionsDone(int sessions, int devices) {
    return '$sessions session(s) and $devices device(s) signed out. Change your password if you don\'t recognize this login.';
  }

  @override
  String get revokeOtherSessionsError =>
      'Revocation failed. Check your connection, then try again from the security settings.';
}
