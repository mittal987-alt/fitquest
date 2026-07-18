import 'package:flutter/material.dart';
import '../models/team_model.dart';
import '../models/achievement_model.dart';

class TeamAchievementsScreen extends StatelessWidget {
  final TeamModel team;

  const TeamAchievementsScreen({super.key, required this.team});

  static const Color _kBgColor = Color(0xFF0D1117);
  static const Color _kSurfaceColor = Color(0xFF161B22);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("TEAM ACHIEVEMENTS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16, color: Colors.white)),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: kTeamAchievements.length,
        itemBuilder: (context, index) {
          final achievement = kTeamAchievements[index];
          final isUnlocked = team.unlockedAchievements.contains(achievement.id);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isUnlocked ? _kSurfaceColor : Colors.black26,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isUnlocked ? achievement.color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnlocked ? achievement.color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    achievement.icon,
                    color: isUnlocked ? achievement.color : Colors.white10,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.title,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white : Colors.white24,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.description,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white38 : Colors.white10,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnlocked)
                  const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 20)
                else
                  const Icon(Icons.lock_outline_rounded, color: Colors.white10, size: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
