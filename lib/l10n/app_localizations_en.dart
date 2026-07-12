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
  String get debtsAndReceivables => 'Debts';

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
  String get addDebtTag => '+ New contact';

  @override
  String get debtBalance => 'Balance';

  @override
  String get recentDebtOperations => 'Recent operations';

  @override
  String get noDebtTags => 'No contact defined';

  @override
  String get deleteDebtConfirm => 'Delete this contact and all its operations?';

  @override
  String get linkToCashFlow => 'Link to cash flow?';

  @override
  String get linkToCashFlowDescription =>
      'If no, this operation will be just a memo.';

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
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingFinish => 'Get Started';
}
