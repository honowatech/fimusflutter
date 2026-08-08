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
  String get thisWeek => 'This week';

  @override
  String get thisMonth => 'This month';

  @override
  String get all => 'All';

  @override
  String get noOperationPeriod => 'No operation for this period.';

  @override
  String get addAccount => 'Add an account';

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
  String get recentOperations => 'Recent actions';

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
  String get myContacts => 'My Contacts';

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
  String get catIncomeSale => 'Sale of goods';

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
}
