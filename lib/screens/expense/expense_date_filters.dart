import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:monitrack/l10n/app_localizations.dart';

/// Libellé du mois précédent utilisé dans le sélecteur de période.
///
/// Le nom du mois vient d'`intl`, qui le rend dans la locale active : aucune
/// liste de mois n'est codée en dur ici.
String lastMonthLabel(BuildContext context) {
  final now = DateTime.now();
  final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
  final lastMonth = now.month == 1 ? 12 : now.month - 1;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMM(locale).format(DateTime(lastMonthYear, lastMonth));
}

/// Convertit un filtre de période en plage de dates.
DateTimeRange expenseRangeFor({
  required String periodFilter,
  DateTimeRange? customDateRange,
}) {
  final now = DateTime.now();
  switch (periodFilter) {
    case '7days':
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      return DateTimeRange(start: start, end: end);
    case '30days':
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      return DateTimeRange(start: start, end: end);
    case 'last_month':
      final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
      final lastMonth = now.month == 1 ? 12 : now.month - 1;
      final lastDayOfLastMonth = DateTime(lastMonthYear, lastMonth + 1, 0).day;
      return DateTimeRange(
        start: DateTime(lastMonthYear, lastMonth, 1, 0, 0, 0, 0),
        end: DateTime(lastMonthYear, lastMonth, lastDayOfLastMonth, 23, 59, 59, 999),
      );
    case 'custom':
      if (customDateRange != null) {
        return customDateRange;
      }
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      return DateTimeRange(start: start, end: end);
    default:
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      return DateTimeRange(start: start, end: end);
  }
}

/// Ouvre le sélecteur de plage personnalisée (6 mois glissants maximum) et
/// renvoie la plage normalisée (00:00:00 → 23:59:59), ou `null` si annulé.
Future<DateTimeRange?> pickExpenseCustomRange(
  BuildContext context,
  DateTimeRange? currentCustomRange,
) async {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
  final firstDate = DateTime(sixMonthsAgo.year, sixMonthsAgo.month, sixMonthsAgo.day);
  final lastDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  final defaultStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  final defaultEnd = DateTime(now.year, now.month, now.day);

  final initialStart = currentCustomRange?.start ?? defaultStart;
  final initialEnd = currentCustomRange?.end ?? defaultEnd;

  final validStart = initialStart.isBefore(firstDate) ? firstDate : initialStart;
  final validEnd = initialEnd.isAfter(lastDate) ? lastDate : initialEnd;

  final picked = await showDateRangePicker(
    context: context,
    initialDateRange: DateTimeRange(start: validStart, end: validEnd),
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: l10n.selectPeriodMax6Months,
    cancelText: l10n.cancel,
    confirmText: l10n.validate,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: child!,
      );
    },
  );

  if (picked == null) return null;

  return DateTimeRange(
    start: DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0, 0),
    end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999),
  );
}

