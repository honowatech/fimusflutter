import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../utils/currency_converter.dart';

/// Agrège les opérations par jour sur la plage donnée, puis par semaine
/// au-delà de 14 points pour garder un graphique lisible.
///
/// Chaque montant est **converti dans [profileCurrency] avant d'être cumulé** :
/// une série qui additionne des devises différentes trace une courbe fausse.
/// Une devise de ligne inconnue (`null`, antérieure au palier 19) est tenue
/// pour déjà exprimée dans celle du profil, conformément au contrat de repli.
List<Map<String, dynamic>> aggregateDailyData(
  List<Expense> expenses,
  DateTimeRange range, {
  required String profileCurrency,
  required Map<String, double> activeRates,
}) {
  final Map<String, Map<String, double>> grouped = {};

  // Create entries for each day in the range
  final totalDays = range.end.difference(range.start).inDays + 1;
  for (int i = 0; i < totalDays; i++) {
    final date = range.start.add(Duration(days: i));
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    grouped[key] = {'income': 0.0, 'expense': 0.0};
  }

  for (final e in expenses) {
    final d = e.date.toLocal();
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if (grouped.containsKey(key)) {
      final amount = CurrencyConverter.convertForDisplay(
        amount: e.amount,
        from: e.currency,
        to: profileCurrency,
        activeRates: activeRates,
      );
      if (e.type == 'income') {
        grouped[key]!['income'] = (grouped[key]!['income'] ?? 0) + amount;
      } else {
        grouped[key]!['expense'] = (grouped[key]!['expense'] ?? 0) + amount;
      }
    }
  }

  final sortedKeys = grouped.keys.toList()..sort();

  // If too many days, aggregate by week
  if (sortedKeys.length > 14) {
    final List<Map<String, dynamic>> weeklyData = [];
    double weekIncome = 0;
    double weekExpense = 0;
    String? weekStartLabel;

    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final parts = key.split('-');
      final day = parts[2];
      final month = parts[1];

      weekStartLabel ??= '$day/$month';
      weekIncome += grouped[key]!['income']!;
      weekExpense += grouped[key]!['expense']!;

      if ((i + 1) % 7 == 0 || i == sortedKeys.length - 1) {
        final endLabel = '$day/$month';
        weeklyData.add({
          'label': weeklyData.length < 6 ? '$weekStartLabel-$endLabel' : '$day/$month',
          'income': weekIncome,
          'expense': weekExpense,
        });
        weekIncome = 0;
        weekExpense = 0;
        weekStartLabel = null;
      }
    }
    return weeklyData;
  }

  return sortedKeys.map((key) {
    final parts = key.split('-');
    final day = parts[2];
    final month = parts[1];
    return {
      'label': '$day/$month',
      'income': grouped[key]!['income']!,
      'expense': grouped[key]!['expense']!,
    };
  }).toList();
}

/// Abrège les montants de l'axe vertical (1.2K, 3.4M…).
String formatChartAmount(double value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  } else if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toStringAsFixed(0);
}
