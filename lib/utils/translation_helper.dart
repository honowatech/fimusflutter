import 'package:monitrack/l10n/app_localizations.dart';

extension CategoryTranslation on AppLocalizations {
  String translateCategory(String category) {
    switch (category) {
      // Expenses
      case 'Alimentation':
      case 'Food':
        return catExpenseFood;
      case 'Transport':
        return catExpenseTransport;
      case 'Loisirs':
      case 'Leisure':
        return catExpenseLeisure;
      case 'Santé':
      case 'Health':
        return catExpenseHealth;
      case 'Factures':
      case 'Bills':
        return catExpenseBills;
      
      // Incomes
      case 'Salaires':
      case 'Salary':
        return catIncomeSalary;
      case 'Pension retraite':
      case 'Pension':
        return catIncomePension;
      case 'Honoraires':
      case 'Fees':
        return catIncomeFees;
      case 'Bénéfices':
      case 'Profits':
        return catIncomeProfits;
      case 'Dividendes':
      case 'Dividends':
        return catIncomeDividends;
      case 'Vente de bien':
      case 'Sale of goods':
        return catIncomeSale;
      case 'Dons':
      case 'Donations':
        return catIncomeDonations;
      case 'Héritages':
      case 'Inheritance':
        return catIncomeInheritance;
      
      // USSD Categories
      case 'Dépôt':
      case 'Deposit':
        return catUssdDeposit;
      case 'Retrait':
      case 'Withdrawal':
        return catUssdWithdrawal;
      case 'Transfert':
      case 'Transfer':
        return catUssdTransfer;
      case 'Paiement marchand':
      case 'Merchant Payment':
        return catUssdMerchantPayment;
      case 'Crédit':
      case 'Airtime':
        return catUssdCredit;
      case 'Solde':
      case 'Balance':
        return catUssdBalance;
      case 'Internet':
        return catUssdInternet;

      // Common
      case 'Autre':
      case 'Other':
        // we can return catExpenseOther (which is identical text) 
        // to handle the general 'Other'
        return catExpenseOther;
        
      default:
        return category;
    }
  }

  String translateUssdAction(String action) {
    switch (action) {
      case 'Dépôt d\'argent (Cash-In)':
      case 'Cash-In':
        return ussdActionCashIn;
      case 'Retrait client (Cash-Out Agent)':
      case 'Cash-Out (Agent)':
        return ussdActionCashOutAgent;
      case 'Retrait d\'argent (Code client)':
      case 'Cash-Out (Client code)':
        return ussdActionCashOutClient;
      case 'Transfert d\'argent':
      case 'Money Transfer':
        return ussdActionTransfer;
      case 'Paiement marchand':
      case 'Merchant Payment':
        return ussdActionMerchant;
      case 'Solde compte Agent/UV':
      case 'Agent/UV Balance':
        return ussdActionBalanceAgent;
      case 'Achat crédit':
      case 'Buy Airtime':
        return ussdActionCredit;
      case 'Dépôt d\'argent (Cash-In Agent)':
      case 'Cash-In (Agent)':
        return ussdActionCashInAgent;
      case 'Solde compte Flotte/Agent':
      case 'Fleet/Agent Balance':
        return ussdActionBalanceFleet;
      case 'Achat forfait Internet':
      case 'Buy Internet Data':
        return ussdActionInternet;
      default:
        return action;
    }
  }
}
