import 'package:monitrack/models/account.dart';
import 'package:monitrack/models/expense.dart';
import 'package:monitrack/models/notification_preferences.dart';

/// Fabriques communes aux tests d'alertes locales.
///
/// Volontairement minimalistes : seuls les champs que l'évaluateur consulte
/// réellement (type, trésorerie, prévisionnel, statut de programmation,
/// catégorie, montant, date) sont paramétrables.

/// Mois de référence des tests : septembre 2026.
final DateTime moisCourant = DateTime(2026, 9, 15, 12, 0);

Expense depense({
  String id = 'exp-1',
  String categorie = 'Transport',
  double montant = 0,
  DateTime? date,
  String type = 'expense',
  bool prevision = false,
  bool tresorerie = true,
  String? statutProgrammation,
}) {
  return Expense(
    id: id,
    title: 'Opération $id',
    amount: montant,
    category: categorie,
    date: date ?? DateTime(2026, 9, 10),
    type: type,
    isLinkedToCashFlow: tresorerie,
    isPlanned: prevision,
    scheduleStatus: statutProgrammation,
  );
}

Account compte({
  String id = 'acc-1',
  String nom = 'Compte courant',
  double solde = 0,
}) {
  return Account(id: id, name: nom, balance: solde);
}

/// Préférences sans heures calmes (cas nominal).
const NotificationPreferences sansHeuresCalmes = NotificationPreferences();

/// Préférences avec heures calmes 22:00 → 07:00 (plage à cheval sur minuit).
const NotificationPreferences avecHeuresCalmes = NotificationPreferences(
  quietHoursEnabled: true,
  quietHoursStart: '22:00',
  quietHoursEnd: '07:00',
);
