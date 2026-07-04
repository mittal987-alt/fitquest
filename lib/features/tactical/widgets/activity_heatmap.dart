import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ActivityHeatmap extends StatelessWidget {
  final Map<String, dynamic> hourlyTelemetry;

  const ActivityHeatmap({super.key, required this.hourlyTelemetry});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _buildBars(),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBars() {
    List<BarChartGroupData> bars = [];
    for (int i = 0; i < 24; i++) {
      // Safely parse the steps for this hour
      int steps = int.tryParse(hourlyTelemetry[i.toString()].toString()) ?? 0;

      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: steps.toDouble(),
              // Intensity logic: High activity shows as orange, low as blue
              color: steps > 500 ? Colors.orangeAccent : Colors.blueAccent,
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    return bars;
  }
}