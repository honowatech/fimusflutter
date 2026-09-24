import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// Bandeau récapitulatif : dépenses et entrées sur les 7 derniers jours.
class WeeklySummaryBand extends StatelessWidget {
  const WeeklySummaryBand({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    final expenseProvider = context.watch<ExpenseProvider>();
    final currency = context.watch<ProfileProvider>().profile.currency;

    final expenses = expenseProvider.getTotalExpenses(start, now);
    final incomes = expenseProvider.getTotalIncomes(start, now);

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
                    amount: expenses,
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
                    amount: incomes,
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
    required this.amount,
    required this.currency,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double amount;
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
                amount.formatAmount(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                currency,
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
