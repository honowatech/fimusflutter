/// Utility class for converting monetary amounts between currencies.
///
/// Uses a base currency (USD) pivot approach: converts source → USD → target.
/// Rates are provided dynamically from the backend via [ExchangeRateService].
/// A static fallback map ensures offline conversions remain functional.
class CurrencyConverter {
  /// Fallback rates (currency → USD) used when no cached rates are available.
  /// These are approximate and will be overridden by live rates from the backend.
  static const Map<String, double> _fallbackRatesToUsd = {
    'USD': 1.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'XAF': 610.0,
    'XOF': 610.0,
    'NGN': 1500.0,
    'JPY': 155.0,
    'GNF': 8600.0,
    'CDF': 2800.0,
    'GHS': 15.0,
    'KES': 130.0,
    'ZAR': 18.0,
    'MAD': 10.0,
    'TND': 3.1,
    'EGP': 48.0,
    'INR': 83.0,
    'CNY': 7.25,
    'BRL': 5.0,
    'CAD': 1.36,
    'AUD': 1.53,
    'CHF': 0.88,
  };

  /// Maps legacy/display currency labels to their ISO 4217 codes.
  /// This handles the case where users have 'CFA', '€', '$', '£' stored
  /// in their profile from the old manual currency picker.
  static const Map<String, String> _aliases = {
    'CFA': 'XAF',
    '€': 'EUR',
    '\$': 'USD',
    '£': 'GBP',
  };

  /// Normalizes a currency code by resolving known aliases to ISO codes.
  static String _normalize(String code) => _aliases[code] ?? code;

  /// Forme attendue d'un code stocké en base : trois lettres majuscules
  /// (ISO 4217).
  static final RegExp _isoPattern = RegExp(r'^[A-Z]{3}$');

  /// Normalise une valeur quelconque en code ISO 4217 à trois lettres
  /// majuscules, ou rend `null` si elle n'en est pas un.
  ///
  /// C'est la seule porte d'entrée de la colonne `currency` (modèles,
  /// synchronisation) : ce qui n'est pas reconnu vaut « devise inconnue »,
  /// c'est-à-dire exactement le cas des lignes antérieures au palier 19, et
  /// l'affichage retombe alors sur la devise du profil. Mieux vaut un `NULL`
  /// assumé qu'un code inventé dans une base financière.
  ///
  /// Les libellés hérités du sélecteur manuel (`CFA`, `€`, `$`, `£`) sont
  /// résolus comme partout ailleurs dans cette classe.
  static String? normalizeCode(Object? raw) {
    if (raw == null) return null;
    final trimmed = raw.toString().trim();
    if (trimmed.isEmpty) return null;
    final resolved = _normalize(_aliases.containsKey(trimmed)
        ? trimmed
        : trimmed.toUpperCase());
    final upper = resolved.toUpperCase();
    return _isoPattern.hasMatch(upper) ? upper : null;
  }

  /// Devise à inscrire sur une opération **au moment de sa création** :
  /// celle du compte lié s'il en porte une, sinon celle du profil.
  ///
  /// Règle volontairement centralisée ici plutôt que recopiée dans chaque
  /// provider : une fois posée, cette devise n'est jamais réécrite, c'est ce
  /// qui rend l'historique juste après un changement de pays.
  static String? resolveForNewOperation({
    String? accountCurrency,
    String? profileCurrency,
  }) =>
      normalizeCode(accountCurrency) ?? normalizeCode(profileCurrency);

  /// Convertit [amount] pour l'afficher dans la devise [to], en tenant compte
  /// d'une devise d'origine éventuellement inconnue.
  ///
  /// [from] à `null` (ou non reconnue) signifie « devise inconnue, antérieure
  /// au palier 19 » : le montant est rendu tel quel, comme il l'était avant
  /// l'introduction de la colonne. Aucune conversion n'est devinée.
  static double convertForDisplay({
    required double amount,
    required String? from,
    required String to,
    required Map<String, double> activeRates,
  }) {
    final source = normalizeCode(from);
    if (source == null) return amount;
    return convert(
      amount: amount,
      from: source,
      to: to,
      activeRates: activeRates,
    );
  }

  /// Converts [amount] from currency [from] to currency [to].
  ///
  /// [activeRates] should be the map returned by [ExchangeRateService.getRates()].
  /// If a currency is not found in [activeRates], the fallback rate is used.
  /// If neither source is available, a rate of 1.0 is assumed (no conversion).
  static double convert({
    required double amount,
    required String from,
    required String to,
    required Map<String, double> activeRates,
  }) {
    final normFrom = _normalize(from);
    final normTo = _normalize(to);

    if (normFrom == normTo) return amount;

    final rateFrom = activeRates[normFrom] ?? _fallbackRatesToUsd[normFrom];
    final rateTo = activeRates[normTo] ?? _fallbackRatesToUsd[normTo];

    // If we don't know either currency, return the amount unchanged to avoid data loss.
    if (rateFrom == null || rateTo == null) return amount;

    // Cross-rate via USD pivot: amount / rateFrom = USD value, * rateTo = target value.
    return (amount / rateFrom) * rateTo;
  }

  /// Returns the conversion rate from [from] to [to].
  ///
  /// Useful for displaying the rate to the user before confirming a conversion.
  static double getRate({
    required String from,
    required String to,
    required Map<String, double> activeRates,
  }) {
    final normFrom = _normalize(from);
    final normTo = _normalize(to);

    if (normFrom == normTo) return 1.0;

    final rateFrom = activeRates[normFrom] ?? _fallbackRatesToUsd[normFrom];
    final rateTo = activeRates[normTo] ?? _fallbackRatesToUsd[normTo];

    if (rateFrom == null || rateTo == null) return 1.0;

    return rateTo / rateFrom;
  }

  // ---------------------------------------------------------------------------
  // Imputation d'une opération sur le solde d'un compte
  // ---------------------------------------------------------------------------

  /// Taux de [from] vers [to], ou `null` si l'une des deux devises est
  /// inconnue des taux actifs **et** de la table de repli.
  ///
  /// Différence essentielle avec [getRate], qui rend `1.0` dans ce cas : ici
  /// l'absence de taux est une absence, pas une identité. C'est ce qu'il faut
  /// pour un calcul de solde, où un `1.0` inventé additionne 10 EUR à un
  /// compte en XAF comme s'il s'agissait de 10 XAF.
  static double? strictRate({
    required String from,
    required String to,
    required Map<String, double> activeRates,
  }) {
    final normFrom = normalizeCode(from);
    final normTo = normalizeCode(to);
    if (normFrom == null || normTo == null) return null;
    if (normFrom == normTo) return 1.0;

    final rateFrom = activeRates[normFrom] ?? _fallbackRatesToUsd[normFrom];
    final rateTo = activeRates[normTo] ?? _fallbackRatesToUsd[normTo];
    if (rateFrom == null || rateTo == null) return null;

    return rateTo / rateFrom;
  }

  /// Vrai si le taux de [from] vers [to] ne provient pas des taux actifs mais
  /// de la table de repli statique (mode hors ligne, valeurs approchées).
  static bool _usesFallback(
      String from, String to, Map<String, double> activeRates) {
    if (from == to) return false;
    return !activeRates.containsKey(from) || !activeRates.containsKey(to);
  }

  /// Montant d'une opération, exprimé dans la devise du compte sur lequel il
  /// doit être imputé.
  ///
  /// À appeler **avant** toute addition sur `accounts.balance` : un solde est
  /// une somme homogène, et le delta numérique brut suppose à tort que
  /// l'opération et le compte partagent une devise. Le montant peut être
  /// signé — la conversion est linéaire, un retrait reste un retrait.
  ///
  /// Repli, conforme au contrat de données : une devise `null`, des deux
  /// côtés, vaut « inconnue, antérieure au palier 19 » et est donc réputée
  /// être celle du profil. Deux `null` avec le même profil donnent une
  /// identité, c'est-à-dire exactement le comportement d'aujourd'hui.
  ///
  /// Quand le taux manque, le résultat vaut [ConversionOutcome.rateUnavailable]
  /// et ne porte **aucun montant** : l'appelant ne peut pas appliquer par
  /// mégarde une valeur non convertie. À lui de renoncer à l'écriture et de
  /// le signaler, jamais de retomber sur le montant d'origine.
  static ConvertedAmount amountForAccount({
    required double amount,
    required String? operationCurrency,
    required String? accountCurrency,
    required String? profileCurrency,
    required Map<String, double> activeRates,
  }) {
    final profil = normalizeCode(profileCurrency);
    final source = normalizeCode(operationCurrency) ?? profil;
    final cible = normalizeCode(accountCurrency) ?? profil;

    // Aucune devise exploitable nulle part : rien à convertir, on est dans le
    // monde d'avant le palier 19.
    if (source == null || cible == null || source == cible) {
      return ConvertedAmount._(
        outcome: ConversionOutcome.identity,
        amount: amount,
        from: source,
        to: cible,
        rate: 1.0,
      );
    }

    final rate = strictRate(from: source, to: cible, activeRates: activeRates);
    if (rate == null) {
      return ConvertedAmount._(
        outcome: ConversionOutcome.rateUnavailable,
        amount: null,
        from: source,
        to: cible,
        rate: null,
      );
    }

    return ConvertedAmount._(
      outcome: ConversionOutcome.converted,
      amount: amount * rate,
      from: source,
      to: cible,
      rate: rate,
      approximate: _usesFallback(source, cible, activeRates),
    );
  }
}

/// Issue d'une conversion vers la devise d'un compte.
enum ConversionOutcome {
  /// Même devise de part et d'autre (ou devises inconnues, donc réputées
  /// être celle du profil) : le montant s'applique tel quel.
  identity,

  /// Conversion effectuée avec un taux connu.
  converted,

  /// Taux indisponible : aucun montant exploitable n'est produit.
  rateUnavailable,
}

/// Résultat d'une conversion destinée à un calcul de solde.
///
/// Le montant est délibérément `null` en cas d'échec : un type qui rendrait
/// toujours un `double` inviterait à additionner un montant non converti.
class ConvertedAmount {
  const ConvertedAmount._({
    required this.outcome,
    required this.amount,
    required this.from,
    required this.to,
    required this.rate,
    this.approximate = false,
  });

  final ConversionOutcome outcome;

  /// Montant dans la devise du compte, ou `null` si [outcome] vaut
  /// [ConversionOutcome.rateUnavailable].
  final double? amount;

  /// Devise effective de l'opération après repli sur le profil.
  final String? from;

  /// Devise effective du compte après repli sur le profil.
  final String? to;

  /// Taux appliqué, `null` en cas d'échec.
  final double? rate;

  /// Taux issu de la table de repli statique et non des taux actifs :
  /// exploitable, mais approché. À journaliser, éventuellement à signaler à
  /// l'utilisateur ; ce n'est pas une raison de refuser l'écriture.
  final bool approximate;

  /// Vrai lorsqu'un montant est utilisable pour mettre à jour un solde.
  bool get isUsable => amount != null;

  /// Montant utilisable, ou [orElse] si la conversion a échoué. L'appelant
  /// doit choisir explicitement ce repli — il n'y en a pas de tacite.
  double amountOr(double orElse) => amount ?? orElse;

  /// Message prêt pour un `debugPrint` ou un journal de diagnostic.
  String get diagnostic => switch (outcome) {
        ConversionOutcome.identity => 'aucune conversion nécessaire ($to)',
        ConversionOutcome.converted =>
          'converti $from → $to au taux $rate${approximate ? ' (taux de repli, approché)' : ''}',
        ConversionOutcome.rateUnavailable =>
          'taux $from → $to indisponible : montant non converti, écriture à refuser',
      };
}

