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

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
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
                  color: isUnlocked ? const Color(0xFF1A1A2E) : Colors.black,
                  border: Border.all(
                    color: isUnlocked ? achievement.color : Colors.grey.withValues(alpha: 0.3),
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
                      color: isUnlocked ? achievement.color : Colors.grey,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            achievement.title,
                            style: TextStyle(
                              color: isUnlocked ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            achievement.description,
                            style: TextStyle(
                              color: isUnlocked ? Colors.white70 : Colors.grey.withValues(alpha: 0.6),
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
                            style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                          Text(
                            "${achievement.coinReward} CREDITS",
                            style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 10),
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
