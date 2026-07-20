import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/player_model.dart';
import '../models/achievement_model.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final user = firebaseService.currentUser;

    if (user == null) return const Scaffold(body: Center(child: Text("NOT AUTHENTICATED")));

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("ACHIEVEMENTS", style: TextStyle(fontFamily: 'Orbitron', letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<PlayerModel?>(
        stream: firebaseService.getPlayerStream(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final player = snapshot.data!;
          final unlocked = player.unlockedAchievements;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: kGlobalAchievements.length,
            itemBuilder: (context, index) {
              final achievement = kGlobalAchievements[index];
              final isUnlocked = unlocked.contains(achievement.id);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isUnlocked ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainerLow,
                  border: Border.all(
                    color: isUnlocked ? achievement.color : colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isUnlocked
                      ? [BoxShadow(color: achievement.color.withValues(alpha: 0.1), blurRadius: 8)]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      achievement.icon,
                      size: 40,
                      color: isUnlocked ? achievement.color : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            achievement.title,
                            style: TextStyle(
                              color: isUnlocked ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            achievement.description,
                            style: TextStyle(
                              color: isUnlocked ? colorScheme.onSurface.withValues(alpha: 0.7) : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isUnlocked)
                      Icon(Icons.check_circle, color: achievement.color)
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${achievement.xpReward} XP",
                            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                          Text(
                            "${achievement.coinReward} CREDITS",
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
