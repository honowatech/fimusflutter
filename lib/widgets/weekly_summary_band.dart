import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/profile_provider.dart';
// Outils d'affichage multi-devise mutualisés avec les onglets « Dépenses » :
// le bandeau affiche les mêmes agrégats que le tableau de bord, il doit les
// calculer de la même façon.
import '../screens/expense/currency_display.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// Bandeau récapitulatif : dépenses et entrées sur les 7 derniers jours.
class WeeklySummaryBand extends StatelessWidget {
  const WeeklySummaryBand({super.key});

  @override
  Widget build(BuildContext context) => ExchangeRatesBuilder(
        // Taux récupérés une seule fois pour le bandeau : les deux totaux sont
        // des agrégats, ils mêlent les devises des opérations de la semaine.
        builder: _buildBand,
      );

  Widget _buildBand(BuildContext context, Map<String, double> rates) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    final expenseProvider = context.watch<ExpenseProvider>();
    final currency = context.watch<ProfileProvider>().profile.currency;

    // `getTotalExpenses` / `getTotalIncomes` additionnent des montants bruts :
    // sur un historique multi-devise, le résultat n'est pas un total mal
    // libellé mais un total faux. On convertit donc ligne par ligne avant de
    // sommer, sur le même périmètre d'opérations que ces deux méthodes.
    final expenses = sumConverted(
      expenseProvider.getFilteredExpenses(start, now, type: 'expense'),
      profileCurrency: currency,
      activeRates: rates,
    );
    final incomes = sumConverted(
      expenseProvider.getFilteredExpenses(start, now, type: 'income'),
      profileCurrency: currency,
      activeRates: rates,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.last7Days,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                theme.colorScheme.surface.withValues(alpha: 0.9),
              ],
            ),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: l10n.expenses,
                    icon: Icons.arrow_upward_rounded,
                    color: theme.colorScheme.expense,
                    total: expenses,
                    currency: currency,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: l10n.incomeEntries,
                    icon: Icons.arrow_downward_rounded,
                    color: theme.colorScheme.income,
                    total: incomes,
                    currency: currency,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.total,
    required this.currency,
  });

  final String label;
  final IconData icon;
  final Color color;

  /// Total de la période, déjà ramené à la devise du profil.
  final ConvertedTotal total;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: mutedStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                // Le « ≈ » signale un total issu d'une conversion : aucune clé
                // de traduction ne le dit en mots, et le montant est affiché
                // séparément de son code devise (ligne suivante).
                '${total.converted ? '≈ ' : ''}${total.amount.formatAmount()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                // Devise du profil, normalisée comme partout ailleurs
                // (`CFA` → `XAF`) : le total y a été converti.
                MoneyFormatter.label(null, currency),
                style: mutedStyle?.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
