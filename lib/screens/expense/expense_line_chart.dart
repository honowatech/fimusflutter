import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import 'expense_chart_data.dart';

/// Courbes revenus / dépenses du tableau de bord.
Widget buildExpenseLineChart(
    List<Map<String, dynamic>> data, bool showIncome, bool showExpense, String currency,
    ColorScheme colorScheme) {
  double maxY = 0;
  for (final d in data) {
    if (showIncome) maxY = max(maxY, (d['income'] as double));
    if (showExpense) maxY = max(maxY, (d['expense'] as double));
  }
  if (maxY == 0) maxY = 100;
  maxY = maxY * 1.2;

  final lineBarsData = <LineChartBarData>[];

  if (showIncome) {
    lineBarsData.add(LineChartBarData(
      spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]['income'] as double)),
      isCurved: true,
      curveSmoothness: 0.3,
      color: colorScheme.income,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: data.length <= 14,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3,
          color: colorScheme.surface,
          strokeWidth: 2,
          strokeColor: colorScheme.income,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: colorScheme.income.withValues(alpha: 0.12),
      ),
    ));
  }

  if (showExpense) {
    lineBarsData.add(LineChartBarData(
      spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]['expense'] as double)),
      isCurved: true,
      curveSmoothness: 0.3,
      color: colorScheme.expense,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: data.length <= 14,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3,
          color: colorScheme.surface,
          strokeWidth: 2,
          strokeColor: colorScheme.expense,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: colorScheme.expense.withValues(alpha: 0.12),
      ),
    ));
  }

  return LineChart(
    LineChartData(
      maxY: maxY,
      minY: 0,
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          // PALETTE VOLONTAIREMENT FIGÉE : l'infobulle fl_chart flotte
          // au-dessus du graphique et reste sombre dans les deux thèmes ;
          // `inverseSurface` deviendrait clair en sombre et ferait
          // disparaître les libellés vert/rouge clairs ci-dessous.
          getTooltipColor: (_) => Colors.grey.shade800,
          tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          tooltipMargin: 8,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final isIncome = spot.barIndex == 0 && showIncome;
              final label = isIncome ? '+' : '-';
              return LineTooltipItem(
                '$label${spot.y.formatAmount()} $currency',
                TextStyle(
                  color: isIncome ? Colors.greenAccent : Colors.redAccent.shade100,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
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
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= data.length) return const SizedBox.shrink();
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
      lineBarsData: lineBarsData,
    ),
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
}
