import 'dart:convert';

import 'package:monitrack/models/expense.dart';
import 'package:monitrack/services/database_service.dart';
import 'package:monitrack/utils/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sync_fake_dio.dart';

/// Montage commun aux suites d'imputation de solde (`balance_*`,
/// `providers/account_*`, `providers/expense_*`).
///
/// Trois contraintes dictent ce fichier :
///  * la conversion lit ses taux dans SharedPreferences
///    (`ExchangeRateService.getRates`) et la devise du profil dans la clé
///    `user_profile` : les deux sont donc des **entrées de test**, pas des
///    doubles à injecter ;
///  * les assertions portent sur la **base**, jamais sur l'état en mémoire des
///    providers : un solde faux en base est le défaut qu'on cherche ;
///  * chaque suite tourne sur une base en mémoire (les suites en parallèle sur
///    un fichier partagé provoquent des « database is locked »).

/// Taux « actifs » des tests, choisis pour donner des conversions lisibles :
/// 1 EUR = 750 XOF (600 / 0,80), 1 XOF = 1/750 EUR.
const Map<String, double> tauxTest = <String, double>{
  'USD': 1.0,
  'EUR': 0.80,
  'XAF': 600.0,
  'XOF': 600.0,
};

/// Taux de conversion EUR → XOF (et XAF) induit par [tauxTest].
const double tauxEurVersXof = 750.0;

/// Code ISO valide absent des taux actifs **et** de la table de repli
/// statique : le seul moyen de provoquer un vrai « taux indisponible ».
const String deviseSansTaux = 'SEK';

/// Initialise le moteur SQLite de test (une fois par suite).
void initialiserSqfliteFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Remplace le client HTTP par un Dio qui échoue immédiatement.
///
/// Les providers appellent `SyncService().push()` sans l'attendre après chaque
/// écriture : sans ce court-circuit, chaque test paierait un délai de connexion
/// et un push réussi réécrirait les colonnes `is_synced` que l'on inspecte.
void couperLeReseau() {
  ApiClient.debugOverride(dioFeint((options) => throw panneReseau(options)));
}

/// Préférences du test : devise du profil et taux de change en cache.
///
/// [deviseProfil] à `null` simule un profil absent (premier lancement, isolat
/// de notification) ; [taux] vide simule un appareil hors ligne qui n'a jamais
/// synchronisé ses taux.
void preparerPreferences({
  String? deviseProfil = 'XOF',
  Map<String, double> taux = tauxTest,
  Map<String, Object> extra = const <String, Object>{},
}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (deviseProfil != null)
      'user_profile': json.encode(<String, dynamic>{
        'firstName': 'Test',
        'lastName': 'Fimus',
        'currency': deviseProfil,
        'country': 'Cameroun',
      }),
    'cached_exchange_rates': json.encode(taux),
    ...extra,
  });
}

/// Base en mémoire, vidée à chaque test.
Future<void> preparerBase() async {
  await DatabaseService.instance.switchDatabase(name: inMemoryDatabasePath);
  await DatabaseService.instance.clearDevDatabase();
}

/// Insère un compte directement en base, en le marquant **synchronisé** : toute
/// remise à `is_synced = 0` observée ensuite est donc bien le fait du code
/// testé, et non du montage.
Future<void> insererCompte(
  String id, {
  required double solde,
  String? devise,
  String nom = 'Compte',
}) async {
  final db = await DatabaseService.instance.database;
  await db.insert('accounts', <String, Object?>{
    'id': id,
    'name': nom,
    'balance': solde,
    'currency': devise,
    'is_synced': 1,
    'sync_action': 'updated',
    'updated_at': DateTime(2026, 1, 1).toIso8601String(),
  });
}

/// Ligne `accounts` telle qu'elle est réellement stockée.
Future<Map<String, Object?>> lireCompte(String id) async {
  final db = await DatabaseService.instance.database;
  final rows = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
  return rows.single;
}

/// Solde en base (et non celui que le provider garde en mémoire).
Future<double> soldeEnBase(String id) async =>
    ((await lireCompte(id))['balance'] as num).toDouble();

/// Insère une opération directement en base, marquée **synchronisée**.
///
/// Nécessaire pour monter les cas que les méthodes du provider refuseraient de
/// créer elles-mêmes (une ligne dans une devise sans taux, par exemple) : le
/// test doit pouvoir partir d'une base déjà dans cet état.
Future<void> insererDepense(Expense operation) async {
  final db = await DatabaseService.instance.database;
  await db.insert('expenses', <String, Object?>{
    ...operation.toDbMap(),
    'is_synced': 1,
    'sync_action': 'updated',
    'updated_at': DateTime(2026, 1, 1).toIso8601String(),
  });
}

/// Ligne `expenses` telle qu'elle est stockée, ou `null` si elle n'existe pas.
Future<Map<String, Object?>?> lireDepense(String id) async {
  final db = await DatabaseService.instance.database;
  final rows = await db.query('expenses', where: 'id = ?', whereArgs: [id]);
  return rows.isEmpty ? null : rows.single;
}

/// Nombre de lignes `expenses` en base, suppressions douces incluses.
Future<int> nombreDeDepenses() async {
  final db = await DatabaseService.instance.database;
  return (await db.query('expenses')).length;
}

/// Opération de test. Les valeurs par défaut décrivent une dépense ordinaire
/// rattachée à la trésorerie ; chaque test ne change que ce qui l'intéresse.
Expense operation(
  String id, {
  double montant = 1000,
  String type = 'expense',
  String? devise,
  String? compte,
  String titre = 'Opération',
  String categorie = 'Autre',
  DateTime? date,
  String? tagDette,
  bool tresorerie = true,
  bool prevision = false,
  String? statutProgrammation,
  DateTime? rappel,
}) {
  return Expense(
    id: id,
    title: titre,
    amount: montant,
    currency: devise,
    category: categorie,
    date: date ?? DateTime(2026, 9, 10, 12),
    type: type,
    accountId: compte,
    debtTag: tagDette,
    isLinkedToCashFlow: tresorerie,
    isPlanned: prevision,
    scheduleStatus: statutProgrammation,
    reminderAt: rappel,
  );
}
