import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/sync_service.dart';
import '../utils/currency_converter.dart';
import '../models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/alerts/local_alerts_service.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';

/// Échec de conversion qui interdit une écriture de solde.
///
/// Levée par [AccountProvider.convertDeltaForAccount] et donc par
/// [AccountProvider.updateBalance] quand aucun taux n'est connu entre la devise
/// de l'opération et celle du compte imputé, ni dans les taux synchronisés ni
/// dans la table de repli statique.
///
/// Le contrat est volontairement une **exception** et non un montant de repli :
/// levée depuis l'intérieur d'une transaction SQLite, elle la fait annuler en
/// entier, si bien que ni l'opération ni le solde ne sont écrits. Un solde faux
/// est pire qu'une opération refusée, et il ne se signale pas tout seul.
///
/// Les écrans n'ont pas à l'attraper eux-mêmes : les méthodes combinées
/// d'`ExpenseProvider` (`addExpenseWithBalance`, `updateExpenseWithBalance`,
/// `deleteExpenseAndAdjustBalance`, `deleteDebtTagAndAdjustBalances`,
/// `confirmScheduledExpenseDetailed`) la convertissent en `BalanceWriteResult`.
class BalanceConversionException implements Exception {
  const BalanceConversionException({
    required this.accountId,
    required this.amount,
    required this.from,
    required this.to,
  });

  /// Compte dont l'imputation a été refusée.
  final String accountId;

  /// Montant, dans la devise de l'opération, qui n'a pas pu être converti.
  final double amount;

  /// Devise de l'opération (après repli sur celle du profil), `null` si
  /// indéterminable.
  final String? from;

  /// Devise du compte (après repli sur celle du profil).
  final String? to;

  String get message =>
      'Taux ${from ?? '?'} → ${to ?? '?'} indisponible : imputation de '
      '$amount sur le compte $accountId refusée (écriture annulée).';

  @override
  String toString() => 'BalanceConversionException: $message';
}

class AccountProvider with ChangeNotifier {
  List<Account> _accounts = [];
  Future<void>? _loadFuture;

  List<Account> get accounts => _accounts;

  AccountProvider() {
    loadData();
  }

  Future<void> loadData() {
    return _loadFuture ??= _performLoadData();
  }

  Future<void> _performLoadData() async {
    try {
      final db = await DatabaseService.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('accounts');
      
      _accounts = maps.map((e) => Account.fromDbMap(e)).toList();
      notifyListeners();
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> addAccount(Account account, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseService.instance.database;
    // Devise du compte figée à la création (devise du profil), jamais
    // réécrite ensuite : un changement de pays ne doit pas réinterpréter un
    // solde existant.
    final withCurrency = account.currency == null
        ? account.copyWith(currency: await _profileCurrency())
        : account;
    final updatedAccount = withCurrency.copyWith(updatedAt: DateTime.now());
    await db.insert('accounts', updatedAccount.toDbMap());
    _accounts.add(updatedAccount);
    notifyListeners();
    SyncService().push();
  }

  /// Devise du profil lue localement (SharedPreferences), comme le fait déjà
  /// `ExpenseProvider` : ce provider n'a pas accès à `ProfileProvider`.
  Future<String?> _profileCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      if (profileJson == null) return null;
      return CurrencyConverter.normalizeCode(
          UserProfile.fromJson(json.decode(profileJson)).currency);
    } catch (e) {
      debugPrint('Erreur de lecture de la devise du profil: $e');
      return null;
    }
  }

  Future<void> updateAccount(Account account, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseService.instance.database;
    final updatedAccount = account.copyWith(updatedAt: DateTime.now());
    await db.update(
      'accounts',
      {
        ...updatedAccount.toDbMap(),
        'is_synced': 0,
        'sync_action': 'updated',
        'updated_at': updatedAccount.updatedAt!.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [updatedAccount.id],
    );
    
    final index = _accounts.indexWhere((a) => a.id == updatedAccount.id);
    if (index != -1) {
      _accounts[index] = updatedAccount;
      notifyListeners();
    }
    SyncService().push();
  }

  Future<void> deleteAccount(String id, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseService.instance.database;
    await db.update(
      'accounts',
      {
        'sync_action': 'delete',
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    
    _accounts.removeWhere((a) => a.id == id);
    notifyListeners();
    SyncService().push();
  }

  // ---------------------------------------------------------------------------
  // Imputation d'un mouvement sur un solde (conversion de devise incluse)
  // ---------------------------------------------------------------------------

  /// Marqueur signifiant « l'appelant n'a pas précisé de devise : le delta est
  /// déjà exprimé dans celle du compte ». Valeur par défaut d'`operationCurrency`.
  ///
  /// À distinguer de `null`, qui a un sens **différent et précis** dans le
  /// contrat de la colonne `currency` : « devise inconnue, à interpréter dans
  /// celle du profil » — ce qui peut déclencher une conversion. Sans ce
  /// marqueur, un appelant pas encore migré verrait son delta converti depuis
  /// la devise du profil alors qu'il est déjà dans celle du compte : on
  /// remplacerait un solde faux par un autre.
  ///
  /// La valeur n'est pas un code ISO à trois lettres, donc elle ne peut pas
  /// être confondue avec une devise réelle.
  static const String deviseDuCompteSupposee = '~non-precisee~';

  /// Devises sans sous-unité (exposant 0 en ISO 4217) : un montant y est
  /// toujours un entier. Un solde en XOF portant `61 042,37` n'a aucun sens et
  /// se traînerait dans tous les affichages.
  static const Set<String> _devisesSansDecimale = {
    'XOF', 'XAF', 'XPF', 'GNF', 'KMF', 'DJF', 'RWF', 'BIF', 'UGX',
    'JPY', 'KRW', 'VND', 'CLP', 'PYG', 'ISK',
  };

  /// Arrondi d'un montant **converti** à la précision de [devise] : à l'unité
  /// pour une devise sans sous-unité, au centime sinon.
  ///
  /// Décision produit (à valider) : on arrondit, et seulement après conversion.
  /// Un montant non converti n'est jamais touché — sans quoi une base existante
  /// en XOF avec des centimes verrait ses soldes bouger sans raison. La
  /// contrepartie assumée est un résidu d'au plus une demi-unité par mouvement
  /// converti lorsqu'une opération est saisie puis supprimée ; cet écart est de
  /// toute façon dominé par la variation du taux entre les deux dates, tant que
  /// le taux appliqué n'est pas historisé sur la ligne.
  static double _arrondirPourDevise(double montant, String? devise) {
    if (devise != null && _devisesSansDecimale.contains(devise)) {
      return montant.roundToDouble();
    }
    return (montant * 100).roundToDouble() / 100;
  }

  /// Cœur de conversion partagé, synchrone et sans effet de bord : rend
  /// [amount] exprimé dans [accountCurrency] et arrondi à sa précision.
  ///
  /// Lève [BalanceConversionException] si aucun taux n'est connu. On passe par
  /// [CurrencyConverter.amountForAccount] (et donc par `strictRate`) et jamais
  /// par `getRate`, qui rend `1.0` sur une devise inconnue et additionnerait
  /// 10 EUR à un compte en XAF comme s'il s'agissait de 10 XAF.
  ///
  /// [accountId] ne sert qu'à renseigner l'exception.
  static double convertAmountForAccountCurrency({
    required String accountId,
    required double amount,
    required String? operationCurrency,
    required String? accountCurrency,
    required String? profileCurrency,
    required Map<String, double> activeRates,
  }) {
    // Repli de la devise du profil quand elle est inconnue (aucun profil en
    // cache : premier lancement, isolat de notification, tests). Sans lui, un
    // seul des deux côtés serait exploitable et `amountForAccount` refuserait
    // l'écriture — à tort, car il n'y a alors aucune indication qu'une
    // conversion soit nécessaire : on est exactement dans le monde d'avant le
    // palier 19. On fait donc miroir avec le côté connu, ce qui donne une
    // identité. Dès que les deux côtés portent une devise, ce repli ne joue
    // plus et la conversion (ou le refus) s'applique normalement.
    final profil = CurrencyConverter.normalizeCode(profileCurrency) ??
        CurrencyConverter.normalizeCode(accountCurrency) ??
        CurrencyConverter.normalizeCode(operationCurrency);

    final result = CurrencyConverter.amountForAccount(
      amount: amount,
      operationCurrency: operationCurrency,
      accountCurrency: accountCurrency,
      profileCurrency: profil,
      activeRates: activeRates,
    );

    if (!result.isUsable) {
      throw BalanceConversionException(
        accountId: accountId,
        amount: amount,
        from: result.from,
        to: result.to,
      );
    }

    // Identité : on rend le montant d'origine bit pour bit, sans arrondi, pour
    // qu'un flux mono-devise reste numériquement identique à avant.
    if (result.outcome == ConversionOutcome.identity) return amount;

    if (result.approximate) {
      // Taux de repli statique : exploitable, mais approché — ce n'est pas un
      // motif de refus, c'est un motif de trace.
      debugPrint('Solde compte $accountId : ${result.diagnostic}');
    }
    return _arrondirPourDevise(result.amount!, result.to);
  }

  /// Montant de [amount] (exprimé dans [operationCurrency]) tel qu'il doit
  /// s'ajouter au solde du compte [accountId].
  ///
  /// À appeler **avant** d'ouvrir une transaction pour vérifier qu'un
  /// mouvement est imputable : l'exception part alors qu'aucune écriture n'a
  /// eu lieu. Lève [BalanceConversionException] si le taux manque.
  ///
  /// [operationCurrency] laissé à sa valeur par défaut
  /// ([deviseDuCompteSupposee]) rend [amount] inchangé.
  Future<double> convertDeltaForAccount({
    required String accountId,
    required double amount,
    String? operationCurrency = deviseDuCompteSupposee,
    Map<String, double>? activeRates,
  }) async {
    if (operationCurrency == deviseDuCompteSupposee) return amount;

    final index = _accounts.indexWhere((a) => a.id == accountId);
    final accountCurrency = index == -1 ? null : _accounts[index].currency;

    return convertAmountForAccountCurrency(
      accountId: accountId,
      amount: amount,
      operationCurrency: operationCurrency,
      accountCurrency: accountCurrency,
      profileCurrency: await _profileCurrency(),
      activeRates: activeRates ?? await ExchangeRateService().getRates(),
    );
  }

  /// Ajoute [amountDelta] au solde du compte [accountId], **après conversion**
  /// dans la devise de ce compte.
  ///
  /// [operationCurrency] est la devise dans laquelle [amountDelta] est exprimé,
  /// c'est-à-dire celle de l'opération qui provoque le mouvement
  /// (`expense.currency`). La conversion est faite ici, au centre, plutôt que
  /// chez chaque appelant : c'est le seul endroit par lequel passent toutes les
  /// écritures de solde, et le compte — donc sa devise — y est déjà en mémoire.
  ///
  /// Trois valeurs, trois sens :
  /// - un code ISO (`'EUR'`) → conversion depuis cette devise ;
  /// - `null` → devise inconnue au sens du contrat, donc celle du profil ;
  /// - absent / [deviseDuCompteSupposee] → delta déjà dans la devise du
  ///   compte, aucune conversion (comportement des appelants non encore
  ///   migrés, strictement identique à celui d'avant).
  ///
  /// Lève [BalanceConversionException] si le taux manque : appelée dans une
  /// transaction, elle l'annule en entier. Ne jamais rattraper cette exception
  /// pour appliquer `amountDelta` tel quel.
  Future<void> updateBalance(
    String accountId,
    double amountDelta, {
    String? operationCurrency = deviseDuCompteSupposee,
    DatabaseExecutor? executor,
  }) async {
    // Conversion d'abord : si le taux manque, rien n'est écrit.
    final delta = await convertDeltaForAccount(
      accountId: accountId,
      amount: amountDelta,
      operationCurrency: operationCurrency,
    );

    // Index relu après l'attente : la liste a pu bouger entre-temps.
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index != -1) {
      final account = _accounts[index];
      final updatedAccount = account.copyWith(balance: account.balance + delta);
      await updateAccount(updatedAccount, executor: executor);
      // Alerte « solde bas » : évaluée ici plutôt que dans l'écran appelant,
      // donc pour tout mouvement qui passe par ce provider. La confirmation
      // d'une dépense programmée, elle, écrit le solde en SQL direct et
      // évalue de son côté (voir `ExpenseProvider`).
      unawaited(LocalAlertsService.instance
          .evaluate(expenses: const [], accounts: _accounts));
    }
  }

  double getTotalBalance() {
    return _accounts.fold(0.0, (sum, item) => sum + item.balance);
  }

  /// Vide l'état en mémoire (déconnexion) : la base locale est purgée par
  /// ailleurs, l'UI ne doit plus afficher les données de l'ancien compte.
  void clear() {
    _accounts = [];
    notifyListeners();
  }

  Future<void> shareAccount(String accountId, int contactId) async {
    final dio = ApiClient.instance;

    try {
      final response = await dio.post(
        '${ApiConfig.baseUrl}/accounts/$accountId/share',
        data: {'contact_id': contactId},
      );

      if (response.statusCode == 200) {
        // Update account locally
        final index = _accounts.indexWhere((a) => a.id == accountId);
        if (index != -1) {
          final updatedAccount = _accounts[index].copyWith(isShared: true);
          await updateAccount(updatedAccount);
        }
      }
    } catch (e) {
      throw Exception('Erreur lors du partage du compte : $e');
    }
  }

  Future<void> shareAccountWithMultiple(String accountId, List<int> contactIds) async {
    if (contactIds.isEmpty) return;
    
    final dio = ApiClient.instance;

    int successCount = 0;
    List<String> errors = [];

    for (final contactId in contactIds) {
      try {
        final response = await dio.post(
          '${ApiConfig.baseUrl}/accounts/$accountId/share',
          data: {'contact_id': contactId},
        );
        if (response.statusCode == 200) {
          successCount++;
        }
      } catch (e) {
        debugPrint('Erreur partage contact $contactId: $e');
        errors.add(e.toString());
      }
    }

    if (successCount > 0) {
      final index = _accounts.indexWhere((a) => a.id == accountId);
      if (index != -1) {
        final updatedAccount = _accounts[index].copyWith(isShared: true);
        await updateAccount(updatedAccount);
      }
    }

    if (successCount == 0 && errors.isNotEmpty) {
      throw Exception(errors.first);
    }
  }

  Future<List<Map<String, dynamic>>> getAccountMembers(String accountId) async {
    final dio = ApiClient.instance;

    try {
      final response = await dio.get('${ApiConfig.baseUrl}/accounts/$accountId/members');
      if (response.statusCode == 200) {
        final data = response.data;
        return List<Map<String, dynamic>>.from(data['members'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Erreur lors de la récupération des membres : $e');
      return [];
    }
  }
}
