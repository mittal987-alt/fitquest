import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ActivityHeatmap extends StatelessWidget {
  final Map<String, int> hourlySteps;
  final Map<String, int>? ghostBaseline;

  const ActivityHeatmap({
    super.key, 
    required this.hourlySteps, 
    this.ghostBaseline
  });

  @override
  Widget build(BuildContext context) {
    int maxGhostSteps = 0;
    if (ghostBaseline != null) {
      for (var val in ghostBaseline!.values) {
        if (val > maxGhostSteps) maxGhostSteps = val;
      }
    }

    return AspectRatio(
      aspectRatio: 1.7,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: const Color(0xFF161B22).withValues(alpha: 0.9),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "ACTIVITY\n",
                  const TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 10
                  ),
                  children: [
                    TextSpan(
                      text: "${rod.toY.toInt()} steps",
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.w900, 
                        fontSize: 12
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 4 != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "${value.toInt()}:00",
                      style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 9),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: _buildBars(maxGhostSteps),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBars(int _) {
    List<BarChartGroupData> bars = [];
    for (int i = 0; i < 24; i++) {
      final String hourKey = i.toString().padLeft(2, '0');
      int steps = hourlySteps[hourKey] ?? 0;
      int ghostSteps = ghostBaseline?[hourKey] ?? 0;

      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: steps.toDouble(),
              color: steps >= ghostSteps ? Colors.cyanAccent : Colors.cyanAccent.withValues(alpha: 0.4),
              width: 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: ghostSteps.toDouble(),
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      );
    }
    return bars;
  }
}

extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
