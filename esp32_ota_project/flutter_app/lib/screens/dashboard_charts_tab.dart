/// @file dashboard_charts_tab.dart
/// @brief Time-series Charts tab for the industrial dashboard.
///
/// Three line charts using fl_chart:
///   - Heap memory over time
///   - Uptime over time
///   - Tick count / tick rate over time

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/dashboard_data_service.dart';

class DashboardChartsTab extends StatelessWidget {
  final DashboardDataService dataService;

  const DashboardChartsTab({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dataService,
      builder: (_, __) {
        final history = dataService.history;

        if (history.isEmpty) {
          return const Center(child: Text('Collecting data...'));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Heap Chart
            SizedBox(
              height: 200,
              child: _ChartCard(
                title: 'Heap Memory (KB)',
                color: Colors.green,
                child: _buildHeapChart(history),
              ),
            ),
            const SizedBox(height: 12),

            // Uptime Chart
            SizedBox(
              height: 200,
              child: _ChartCard(
                title: 'Uptime (seconds)',
                color: Colors.blue,
                child: _buildUptimeChart(history),
              ),
            ),
            const SizedBox(height: 12),

            // Tick Count Chart
            SizedBox(
              height: 200,
              child: _ChartCard(
                title: 'Tick Count',
                color: Colors.orange,
                child: _buildTickChart(history),
              ),
            ),
            const SizedBox(height: 12),

            // Tick Rate Chart (derived)
            SizedBox(
              height: 200,
              child: _ChartCard(
                title: 'Tick Rate (ticks/s)',
                color: Colors.purple,
                child: _buildTickRateChart(history),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Heap Chart ---

  Widget _buildHeapChart(List<DashboardSnapshot> history) {
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      final heap = history[i].freeHeap ?? 0;
      spots.add(FlSpot(i.toDouble(), heap / 1024.0)); // KB
    }
    return _LineChartBody(
      spots: spots,
      color: Colors.green,
      unit: 'KB',
      maxY: _calcMax(spots) * 1.2,
    );
  }

  // --- Uptime Chart ---

  Widget _buildUptimeChart(List<DashboardSnapshot> history) {
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), (history[i].uptimeSeconds ?? 0).toDouble()));
    }
    return _LineChartBody(
      spots: spots,
      color: Colors.blue,
      unit: 's',
      maxY: _calcMax(spots) * 1.1,
    );
  }

  // --- Tick Count Chart ---

  Widget _buildTickChart(List<DashboardSnapshot> history) {
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), (history[i].tickCount ?? 0).toDouble()));
    }
    return _LineChartBody(
      spots: spots,
      color: Colors.orange,
      unit: '',
      maxY: _calcMax(spots) * 1.1,
    );
  }

  // --- Tick Rate Chart (derived from consecutive snapshots) ---

  Widget _buildTickRateChart(List<DashboardSnapshot> history) {
    final spots = <FlSpot>[];
    for (int i = 1; i < history.length; i++) {
      final rate = DashboardSnapshot.computeTickRate(history[i - 1], history[i]);
      if (rate != null) {
        spots.add(FlSpot(i.toDouble(), rate));
      }
    }
    return _LineChartBody(
      spots: spots,
      color: Colors.purple,
      unit: 't/s',
      maxY: spots.isEmpty ? 10 : _calcMax(spots) * 1.3,
    );
  }

  static double _calcMax(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    return spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
  }
}

// ============================================================================
// Chart Card wrapper
// ============================================================================

class _ChartCard extends StatelessWidget {
  final String title;
  final Color color;
  final Widget child;

  const _ChartCard({required this.title, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Reusable line chart with fl_chart
// ============================================================================

class _LineChartBody extends StatelessWidget {
  final List<FlSpot> spots;
  final Color color;
  final String unit;
  final double maxY;

  const _LineChartBody({
    required this.spots,
    required this.color,
    required this.unit,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridColor = isDark ? Colors.white24 : Colors.grey[300]!;
    final textColor = isDark ? Colors.white54 : Colors.grey[600]!;

    return LineChart(
      LineChartData(
        maxY: maxY > 0 ? maxY : 1,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _niceInterval(maxY),
          getDrawingHorizontalLine: (value) => FlLine(color: gridColor, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: _niceInterval(maxY),
              getTitlesWidget: (value, meta) => Text(
                '${value.toStringAsFixed(value >= 100 ? 0 : 1)}',
                style: TextStyle(fontSize: 10, color: textColor, fontFamily: 'RobotoMono'),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: FlDotData(show: spots.length < 20),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} $unit',
                TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static double _niceInterval(double maxVal) {
    if (maxVal <= 0) return 1;
    final rough = maxVal / 4;
    final mag = rough == 0 ? 1 : pow(10, (log(rough) / ln10).floor()).toDouble();
    final residual = rough / mag;
    if (residual <= 1.5) return mag;
    if (residual <= 3) return 2 * mag;
    if (residual <= 7) return 5 * mag;
    return 10 * mag;
  }
}