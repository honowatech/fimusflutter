import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../services/exchange_rate_service.dart';
import '../../utils/currency_converter.dart';
import '../../utils/formatters.dart';

/// Outils d'affichage multi-devise partagés par les onglets « Dépenses » et par
/// le bandeau hebdomadaire de l'accueil.
///
/// Deux cas qu'il ne faut pas confondre :
/// * une **opération isolée** s'affiche dans la devise où elle a été saisie
///   ([MoneyFormatter.format]) : la convertir reviendrait à réécrire ce que
///   l'utilisateur a tapé ;
/// * un **agrégat** (total de période, solde, série de graphique) mêle des
///   devises. Additionner les montants bruts ne donne pas un total mal
///   libellé mais un total **faux** : chaque ligne est donc convertie avant la
///   somme, puis le total est libellé dans la devise du profil.

/// Somme d'un agrégat multi-devise, ramenée à la devise du profil.
class ConvertedTotal {
  const ConvertedTotal(this.amount, {required this.converted});

  /// Total exprimé dans la devise du profil.
  final double amount;

  /// Vrai si au moins une ligne portait une devise étrangère : le total est
  /// alors le produit d'une conversion, ce que l'interface doit signaler.
  final bool converted;
}

/// Convertit chaque ligne de [expenses] dans [profileCurrency] puis les
/// additionne.
///
/// Le passage par [CurrencyConverter.convertForDisplay] — le même que celui
/// utilisé par [MoneyFormatter.formatConverted] — garantit le contrat du
/// palier 19 : une devise `null` ou non reconnue est « inconnue », donc
/// considérée comme déjà exprimée dans celle du profil, et rien n'est deviné.
///
/// [MoneyFormatter.formatConverted] ne peut pas faire ce travail : il convertit
/// un montant depuis **une** devise d'origine, alors qu'un total en mêle
/// plusieurs. Convertir la somme brute reviendrait à appliquer un seul taux à
/// des montants hétérogènes.
ConvertedTotal sumConverted(
  Iterable<Expense> expenses, {
  required String profileCurrency,
  required Map<String, double> activeRates,
}) {
  var total = 0.0;
  var converted = false;
  for (final e in expenses) {
    if (MoneyFormatter.isForeign(e.currency, profileCurrency)) converted = true;
    total += CurrencyConverter.convertForDisplay(
      amount: e.amount,
      from: e.currency,
      to: profileCurrency,
      activeRates: activeRates,
    );
  }
  return ConvertedTotal(total, converted: converted);
}

/// Libellé d'un agrégat : montant dans la devise du profil, préfixé de « ≈ »
/// quand il résulte d'une conversion.
///
/// Le « ≈ » tient lieu de mention : aucune clé de traduction existante ne dit
/// « montant converti », et le lot de finition n'autorise pas à en ajouter. Le
/// signe est par ailleurs compris dans les deux langues de l'application.
String formatAggregate(
  ConvertedTotal total, {
  required String profileCurrency,
  int? decimalPlaces,
  String prefix = '',
}) {
  final body = MoneyFormatter.format(
    total.amount,
    rowCurrency: profileCurrency,
    profileCurrency: profileCurrency,
    decimalPlaces: decimalPlaces,
  );
  return '${total.converted ? '≈ ' : ''}$prefix$body';
}

/// Fournit les taux de change à un sous-arbre, chargés **une seule fois**.
///
/// [ExchangeRateService.getRates] est asynchrone (cache SharedPreferences) :
/// l'appeler depuis un `build` le relancerait à chaque reconstruction, et une
/// fois par ligne de liste dans le pire des cas. Cet état le récupère à
/// l'initialisation et le conserve pour tout l'écran.
///
/// Au premier frame la carte est vide, ce que [CurrencyConverter] interprète
/// comme « aucun taux en cache » et traite avec sa table statique de repli :
/// l'affichage est approximatif pendant un frame puis affiné, plutôt que
/// remplacé par un indicateur de chargement qui ferait clignoter l'écran.
class ExchangeRatesBuilder extends StatefulWidget {
  const ExchangeRatesBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, Map<String, double> rates) builder;

  @override
  State<ExchangeRatesBuilder> createState() => _ExchangeRatesBuilderState();
}

class _ExchangeRatesBuilderState extends State<ExchangeRatesBuilder> {
  Map<String, double> _rates = const {};

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    final rates = await ExchangeRateService().getRates();
    // Carte vide = pas de cache : inutile de reconstruire, la table de repli
    // de `CurrencyConverter` est déjà ce qui est appliqué.
    if (!mounted || rates.isEmpty) return;
    setState(() => _rates = rates);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _rates);
}
