import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class WeeklyStepChart extends StatelessWidget {
  final Map<String, dynamic> dailyHistory;
  final int targetSteps;

  const WeeklyStepChart({
    super.key,
    required this.dailyHistory,
    required this.targetSteps,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final List<BarChartGroupData> barGroups = [];
    final List<String> labels = [];

    // Process last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = date.toIso8601String().split('T')[0];
      final data = dailyHistory[key];
      final double steps = (data?['steps'] as num?)?.toDouble() ?? 0.0;
      
      labels.add(DateFormat('E').format(date).toUpperCase());

      final bool isGoalMet = steps >= targetSteps;

      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: steps,
              color: isGoalMet ? Colors.greenAccent : Colors.blueAccent,
              width: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: targetSteps.toDouble(),
                color: Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (barGroups.map((e) => e.barRods[0].toY).reduce((a, b) => a > b ? a : b) * 1.2).clamp(targetSteps * 1.2, double.infinity),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.white,
              tooltipBorder: const BorderSide(color: Colors.black12),
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tooltipRoundedRadius: 12,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final date = now.subtract(Duration(days: 6 - group.x.toInt()));
                final dateKey = date.toIso8601String().split('T')[0];
                final dayData = dailyHistory[dateKey];
                final bool hadTraining = dayData?['trainingSessions'] != null;
                
                return BarTooltipItem(
                  "${rod.toY.toInt()} steps\n",
                  const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                  children: [
                    if (hadTraining)
                      TextSpan(
                        text: "⚔️ TRAINING PROTOCOL ACTIVE",
                        style: TextStyle(color: Colors.orangeAccent.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= labels.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: targetSteps.toDouble(),
                color: Colors.greenAccent.withValues(alpha: 0.2),
                strokeWidth: 1,
                dashArray: [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 5, bottom: 5),
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                  labelResolver: (line) => "TARGET",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
