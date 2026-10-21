// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/man_hour_models.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';
import 'man_hour_exporter.dart' show manHourMonthNames;

/// Cross-depot analytics for the man-hour sheets.
///
/// Reads a whole year of sheets in one go and slices it for the month that is
/// selected in the entry view: headline figures, a depot comparison, the
/// workforce-category split and the twelve-month trend.
class ManHourAnalyticsView extends ConsumerWidget {
  const ManHourAnalyticsView({
    super.key,
    required this.year,
    required this.month,
  });

  final int year;
  final int month;

  static const _categoryColors = <ManHourCategory, Color>{
    ManHourCategory.fte: Color(0xFF1F4E79),
    ManHourCategory.dso: Color(0xFF2E9BA6),
    ManHourCategory.contractor: Color(0xFFE08A2B),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final yearData = ref.watch(manHourYearProvider(year));
    final depotNames = ref.watch(depotNameMapProvider);

    return yearData.when(
      loading: () => const LoadingView(message: 'Loading man-hour analytics…'),
      error: (e, _) => ErrorView(message: readableError(e)),
      data: (data) {
        final depots = _depotTotals(data, depotNames);
        final totalHours = depots.fold(0, (a, d) => a + d.hours);
        final totalWorkers = depots.fold(0, (a, d) => a + d.workers);
        final reporting = depots.where((d) => d.hours > 0).length;
        final submitted = data
            .sheetsForMonth(month)
            .where((s) => s.isSubmitted)
            .length;

        final previous = month == 1 ? 0 : data.totalForMonth(month - 1);
        final delta = previous == 0
            ? (totalHours == 0 ? 0.0 : 100.0)
            : ((totalHours - previous) / previous) * 100;

        final categories = data.byCategoryForMonth(month);
        final monthlyTrend = List<int>.generate(12, (i) => data.totalForMonth(i + 1));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Analytics — ${manHourMonthNames[month - 1]} $year',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: KpiTile(
                    label: 'Man-hours this month',
                    value: _compact(totalHours),
                    icon: Icons.schedule_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KpiTile(
                    label: 'vs previous month',
                    value: '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
                    icon: delta >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: delta >= 0
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: KpiTile(
                    label: 'Workers on the sheets',
                    value: '$totalWorkers',
                    icon: Icons.groups_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KpiTile(
                    label: 'Depots reporting',
                    value: '$reporting / ${depots.length}',
                    icon: Icons.storefront_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KpiTile(
                    label: 'Sheets submitted',
                    value: '$submitted / ${data.sheetsForMonth(month).length}',
                    icon: Icons.verified_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _panel(
              theme,
              'Man-hours by depot',
              depots.isEmpty
                  ? const EmptyView(
                      message: 'No depot has recorded man-hours for this month.',
                    )
                  : SizedBox(
                      height: 260,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _maxY(depots.map((d) => d.hours)),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (v) => FlLine(
                              color: theme.dividerColor.withValues(alpha: 0.3),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 42,
                                getTitlesWidget: (value, _) => Text(
                                  _compact(value.toInt()),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 34,
                                getTitlesWidget: (value, _) {
                                  final index = value.toInt();
                                  if (index < 0 || index >= depots.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      depots[index].name,
                                      style: theme.textTheme.labelSmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: depots.asMap().entries.map((e) {
                            final d = e.value;
                            return BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: d.hours.toDouble(),
                                  color: theme.colorScheme.primary,
                                  width: 16,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            _panel(
              theme,
              'Workforce mix',
              categories.isEmpty
                  ? const EmptyView(
                      message: 'No category has been recorded for this month.',
                    )
                  : SizedBox(
                      height: 240,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 46,
                          sections: categories.entries.map((e) {
                            final share = totalHours == 0
                                ? 0.0
                                : (e.value / totalHours) * 100;
                            return PieChartSectionData(
                              value: e.value.toDouble(),
                              color: _categoryColors[e.key] ??
                                  theme.colorScheme.primary,
                              radius: 64,
                              title: share < 1 ? '' : '${share.toStringAsFixed(0)}%',
                              titleStyle: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: ManHourCategory.values.map((c) {
                final value = categories[c] ?? 0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _categoryColors[c] ?? theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${c.label} — ${_compact(value)} h',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _panel(
              theme,
              'Twelve-month trend ($year)',
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (value, _) => Text(
                            _compact(value.toInt()),
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          interval: 1,
                          getTitlesWidget: (value, _) {
                            final index = value.toInt();
                            if (index < 0 || index > 11) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                manHourMonthNames[index].substring(0, 3),
                                style: theme.textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List<FlSpot>.generate(
                          12,
                          (i) => FlSpot(i + 1, monthlyTrend[i].toDouble()),
                        ),
                        isCurved: true,
                        color: theme.colorScheme.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _panel(
              theme,
              'Depot summary',
              depots.isEmpty
                  ? const EmptyView(message: 'No sheets recorded yet.')
                  : Column(
                      children: [
                        for (final d in depots)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    d.name,
                                    style: theme.textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${d.workers}',
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${d.hours}',
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    totalHours == 0
                                        ? '0%'
                                        : '${((d.hours / totalHours) * 100).toStringAsFixed(1)}%',
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'TOTAL',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '$totalWorkers',
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '$totalHours',
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _panel(ThemeData theme, String title, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );

  List<_DepotTotal> _depotTotals(
    ManHourYearData data,
    Map<String, String> names,
  ) {
    final out = <_DepotTotal>[];
    for (final sheet in data.sheetsForMonth(month)) {
      final entries = data.entriesFor(sheet.id);
      out.add(
        _DepotTotal(
          name: sheet.depotName.isEmpty
              ? (names[sheet.depotId] ?? 'Unnamed depot')
              : sheet.depotName,
          workers: entries.fold(0, (a, e) => a + e.workerCount),
          hours: entries.fold(0, (a, e) => a + e.total),
        ),
      );
    }
    out.sort((a, b) => b.hours.compareTo(a.hours));
    return out;
  }

  static double _maxY(Iterable<int> values) {
    var max = 0;
    for (final v in values) {
      if (v > max) max = v;
    }
    if (max == 0) return 10;
    return (max * 1.25).roundToDouble();
  }

  static String _compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }
}

class _DepotTotal {
  const _DepotTotal({
    required this.name,
    required this.workers,
    required this.hours,
  });

  final String name;
  final int workers;
  final int hours;
}
