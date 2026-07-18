import 'package:flutter/material.dart';

import '../models/player_model.dart';

class PlayerTile extends StatelessWidget {
  final PlayerModel player;
  final int rank;
  final String? subtitle;

  const PlayerTile({
    super.key,
    required this.player,
    required this.rank,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor = Colors.blue;
    IconData trophyIcon = Icons.workspace_premium;

    // =====================
    // TOP RANK COLORS
    // =====================
    if (rank == 1) {
      rankColor = Colors.amber;
    } else if (rank == 2) {
      rankColor = Colors.grey;
    } else if (rank == 3) {
      rankColor = Colors.brown;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // =====================
          // RANK / AVATAR
          // =====================
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: rankColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: player.avatar.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(player.avatar, fit: BoxFit.cover),
                      )
                    : CircleAvatar(
                        backgroundColor: rankColor.withValues(alpha: 0.1),
                        child: Icon(Icons.person_rounded, color: rankColor, size: 30),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: rankColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF161B22), width: 2),
                  ),
                  child: Text(
                    "#$rank",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // =====================
          // PLAYER INFO
          // =====================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ?? "👣 ${player.totalSteps} Steps",
                  style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  "👥 ${player.team}",
                  style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  "⭐ Level ${player.level}",
                  style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (player.streakCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "🔥 ${player.streakCount} Day Streak",
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // =====================
          // TROPHY
          // =====================
          Icon(
            trophyIcon,
            color: rankColor,
            size: 34,
          ),
        ],
      ),
    );
  }
}
