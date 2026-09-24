import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../providers/expense_provider.dart';
import 'local_alerts_service.dart';

/// Point de branchement unique des alertes locales.
///
/// Les données ne sont **pas** rechargées : on réutilise celles déjà en
/// mémoire dans `ExpenseProvider` et `AccountProvider`. La lecture des
/// providers est faite de façon synchrone, avant tout `await`, pour ne pas
/// dépendre d'un `BuildContext` devenu invalide.
///
/// Appelants prévus (à câbler par le coordinateur, ces fichiers étant hors du
/// périmètre de ce sprint) :
///  * `ExpenseProvider.addExpense` / `updateExpense` / `deleteExpense` — une
///    dépense fait bouger un budget et un solde ;
///  * `AccountProvider.updateBalance` — une opération fait passer un compte
///    sous son seuil ;
///  * `NotificationService.syncAndRefreshProviders()` — après `fullSync`, une
///    synchronisation peut faire bouger les soldes et vider la file d'attente ;
///  * reprise de l'application au premier plan (`main.dart`) — c'est le
///    passage qui rattrape les alertes retenues pendant les heures calmes.
///
/// [force] contourne l'anti-rebond : à réserver aux actions explicites
/// (changement de réglage d'alerte, tirer pour rafraîchir).
Future<AlertRunReport> runLocalAlerts(
  BuildContext context, {
  bool force = false,
}) {
  final expenses = context.read<ExpenseProvider>().expenses;
  final accounts = context.read<AccountProvider>().accounts;
  return LocalAlertsService.instance.evaluate(
    expenses: expenses,
    accounts: accounts,
    force: force,
  );
}
