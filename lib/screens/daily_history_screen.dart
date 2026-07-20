import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/player_model.dart';
import '../features/tactical/widgets/activity_heatmap.dart';
import '../services/pedometer_service.dart';
import '../widgets/weekly_step_chart.dart';

class DailyHistoryScreen extends StatelessWidget {
  final PlayerModel player;

  const DailyHistoryScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    // Standard design tokens
    const double kCardRadius = 24;
    const double kSectionGap = 20;

    // Generate the last 7 days to ensure no "gaps" in history
    final now = DateTime.now();
    final List<String> displayKeys = [];
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      displayKeys.add(date.toIso8601String().split('T')[0]);
    }

    // Also include any older keys that have data
    final historyKeys = player.dailyHistory.keys.toList();
    for (var key in historyKeys) {
      if (!displayKeys.contains(key)) {
        displayKeys.add(key);
      }
    }
    displayKeys.sort((a, b) => b.compareTo(a));

    int totalSteps = 0;
    int totalXp = 0;
    double totalCalories = 0;
    double totalDistance = 0;
    int maxSteps = 0;
    int goalsMet = 0;
    String? bestDay;

    for (var key in displayKeys) {
      final data = player.dailyHistory[key];
      if (data == null) continue;
      int steps = (data['steps'] as num?)?.toInt() ?? 0;
      totalSteps += steps;
      totalXp += (data['xpGained'] as num?)?.toInt() ?? 0;
      totalCalories += (data['calories'] as num?)?.toDouble() ?? 0.0;
      totalDistance += (data['distance'] as num?)?.toDouble() ?? 0.0;
      
      if (steps >= player.dailyStepTarget) {
        goalsMet++;
      }

      if (steps > maxSteps) {
        maxSteps = steps;
        bestDay = key;
      }
    }

    double complianceRate = displayKeys.isEmpty ? 0 : (goalsMet / displayKeys.length) * 100;
    String reliabilityGrade = _getReliabilityGrade(complianceRate);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "OPERATIONAL LOGS",
          style: TextStyle(fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: 1.5, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: displayKeys.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: displayKeys.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(
                        totalSteps, 
                        totalXp, 
                        totalDistance, 
                        totalCalories, 
                        complianceRate, 
                        reliabilityGrade,
                        player.streakCount, 
                        displayKeys.length, 
                        bestDay,
                        kCardRadius
                      ),
                      const SizedBox(height: kSectionGap),
                      WeeklyStepChart(
                        dailyHistory: player.dailyHistory,
                        targetSteps: player.dailyStepTarget,
                      ),
                      const SizedBox(height: kSectionGap),
                      Text(
                        "HISTORICAL TELEMETRY",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4), letterSpacing: 1),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }
                final dateKey = displayKeys[index - 1];
                final data = (player.dailyHistory[dateKey] as Map<String, dynamic>?) ?? {};
                return _buildHistoryCard(context, dateKey, data, kCardRadius);
              },
            ),
    );
  }

  Widget _buildSummaryCard(
    int totalSteps, 
    int totalXp, 
    double totalDistance, 
    double totalCalories, 
    double compliance, 
    String grade,
    int streak, 
    int days, 
    String? bestDay,
    double radius
  ) {
    String bestDayStr = "N/A";
    if (bestDay != null) {
      try {
        bestDayStr = DateFormat('MMM dd').format(DateTime.parse(bestDay));
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A00E0).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "MISSION ARCHIVE",
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5),
              ),
              Row(
                children: [
                  if (streak > 0) ...[
                    const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "$streak DAY STREAK",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$days DAYS",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryStat("RELIABILITY", grade, Icons.verified_user_rounded, color: Colors.cyanAccent),
              _summaryStat("COMPLIANCE", "${compliance.toInt()}%", Icons.analytics_rounded),
              _summaryStat("DISTANCE", "${totalDistance.toStringAsFixed(1)} KM", Icons.map_rounded),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Colors.white10, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryStat("TOTAL STEPS", NumberFormat.compact().format(totalSteps), Icons.directions_walk),
              _summaryStat("XP ACCRUED", NumberFormat.compact().format(totalXp), Icons.bolt),
              _summaryStat("PEAK DAY", bestDayStr, Icons.star),
            ],
          ),
        ],
      ),
    );
  }

  String _getReliabilityGrade(double compliance) {
    if (compliance >= 90) return "S-RANK";
    if (compliance >= 75) return "A-RANK";
    if (compliance >= 50) return "B-RANK";
    if (compliance >= 25) return "C-RANK";
    return "D-RANK";
  }

  Widget _summaryStat(String label, String value, IconData icon, {Color color = Colors.white60}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color == Colors.white60 ? Colors.cyanAccent : color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: colorScheme.onSurface.withValues(alpha: 0.05)),
          const SizedBox(height: 16),
          Text(
            "NO ARCHIVED TELEMETRY",
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            "Complete a 24h cycle to log performance.",
            style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, String dateKey, Map<String, dynamic> data, double radius) {
    final colorScheme = Theme.of(context).colorScheme;
    DateTime date = DateTime.parse(dateKey);
    int steps = (data['steps'] as num?)?.toInt() ?? 0;
    int xp = (data['xpGained'] as num?)?.toInt() ?? 0;
    double calories = (data['calories'] as num?)?.toDouble() ?? 0.0;
    double distance = (data['distance'] as num?)?.toDouble() ?? 0.0;
    List<dynamic> achievements = data['achievements'] ?? [];

    Map<String, int> hourlySteps = {};
    if (data['hourlySteps'] != null) {
      (data['hourlySteps'] as Map).forEach((k, v) {
        hourlySteps[k.toString()] = (v as num).toInt();
      });
    }

    bool goalReached = steps >= player.dailyStepTarget;
    double progress = (steps / player.dailyStepTarget).clamp(0.0, 1.1);
    final fitnessLevel = PedometerService().getFitnessLevel(steps);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colorScheme.brightness == Brightness.dark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(date).toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 10, 
                      color: goalReached ? Colors.greenAccent : colorScheme.primary, 
                      letterSpacing: 1.5
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(date).toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _tierBadge(fitnessLevel),
                      const SizedBox(width: 8),
                      Text(
                        goalReached ? "STATUS: OPTIMAL" : "STATUS: NOMINAL",
                        style: TextStyle(
                          fontWeight: FontWeight.w900, 
                          fontSize: 9, 
                          color: goalReached ? Colors.greenAccent : colorScheme.onSurfaceVariant.withValues(alpha: 0.4), 
                          letterSpacing: 0.5
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _statusBox(
                goalReached ? "GOAL MET" : "GOAL NOT MET",
                goalReached ? Colors.greenAccent : colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem(context, Icons.directions_walk_rounded, "$steps", "STEPS", Colors.orangeAccent),
              _statItem(context, Icons.local_fire_department_rounded, calories.toStringAsFixed(0), "KCAL", Colors.redAccent),
              _statItem(context, Icons.map_rounded, distance.toStringAsFixed(1), "KM", colorScheme.primary),
              _statItem(context, Icons.bolt_rounded, "+$xp", "XP", Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress > 1.0 ? 1.0 : progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: goalReached 
                        ? [Colors.greenAccent.withValues(alpha: 0.6), Colors.greenAccent] 
                        : [colorScheme.primary.withValues(alpha: 0.6), colorScheme.primary],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          if (progress > 1.0)
             Padding(
               padding: const EdgeInsets.only(top: 6),
               child: Text(
                 "SURPASSED TARGET BY ${(steps - player.dailyStepTarget)} STEPS!",
                 style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
               ),
             ),
          const SizedBox(height: 24),
          Text(
            "ACTIVITY INTENSITY",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4), letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          ActivityHeatmap(
            hourlySteps: hourlySteps,
          ),
          if (achievements.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: achievements.map((a) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.military_tech_rounded, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      a.toString().toUpperCase(),
                      style: TextStyle(color: colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tierBadge(String tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_rounded, size: 10, color: Colors.cyanAccent),
          const SizedBox(width: 4),
          Text(
            tier.toUpperCase(),
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _statusBox(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(text.contains("MET") && !text.contains("NOT") ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _statItem(BuildContext context, IconData icon, String value, String label, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorScheme.onSurface)),
          ],
        ),
        Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }
}
