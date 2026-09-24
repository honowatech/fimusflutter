import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import 'expense_chart_data.dart';

/// Histogramme revenus / dépenses du tableau de bord.
Widget buildExpenseBarChart(
    List<Map<String, dynamic>> data, bool showIncome, bool showExpense, String currency,
    ColorScheme colorScheme) {
  double maxY = 0;
  for (final d in data) {
    if (showIncome) maxY = max(maxY, (d['income'] as double));
    if (showExpense) maxY = max(maxY, (d['expense'] as double));
  }
  if (maxY == 0) maxY = 100;
  maxY = maxY * 1.2;

  final barWidth = data.length <= 7 ? 12.0 : (data.length <= 14 ? 8.0 : 6.0);

  return BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          // PALETTE VOLONTAIREMENT FIGÉE : l'infobulle fl_chart flotte
          // au-dessus du graphique et reste sombre dans les deux thèmes ;
          // `inverseSurface` deviendrait clair en sombre et ferait
          // disparaître les libellés vert/rouge clairs ci-dessous.
          getTooltipColor: (_) => Colors.grey.shade800,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          tooltipMargin: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final d = data[group.x.toInt()];
            final isIncomeBar = rodIndex == 0 && showIncome;
            final value = isIncomeBar ? d['income'] : d['expense'];
            final label = isIncomeBar ? '+' : '-';
            return BarTooltipItem(
              '$label${(value as double).formatAmount()} $currency',
              TextStyle(
                color: isIncomeBar ? Colors.greenAccent : Colors.redAccent.shade100,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox.shrink();
              if (value == meta.max) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  formatChartAmount(value),
                  style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= data.length) return const SizedBox.shrink();
              // Show fewer labels if too many data points
              if (data.length > 7 && index % 2 != 0 && index != data.length - 1) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  data[index]['label'] as String,
                  style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant),
                ),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (value) => FlLine(
          color: colorScheme.outlineVariant,
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(data.length, (i) {
        final d = data[i];
        final rods = <BarChartRodData>[];
        if (showIncome) {
          rods.add(BarChartRodData(
            toY: d['income'] as double,
            color: colorScheme.income,
            width: barWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ));
        }
        if (showExpense) {
          rods.add(BarChartRodData(
            toY: d['expense'] as double,
            color: colorScheme.expense,
            width: barWidth,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ));
        }
        return BarChartGroupData(x: i, barRods: rods, barsSpace: 3);
      }),
    ),
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
}
