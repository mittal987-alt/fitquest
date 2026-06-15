import 'package:flutter/material.dart';

import '../models/player_model.dart';

class PlayerTile extends StatelessWidget {

  final PlayerModel player;

  final int rank;

  const PlayerTile({

    super.key,

    required this.player,

    required this.rank,
  });

  @override
  Widget build(BuildContext context) {

    Color rankColor =
        Colors.blue;

    IconData trophyIcon =
        Icons.workspace_premium;

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

      margin:
      const EdgeInsets.only(
          bottom: 16),

      padding:
      const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(24),

        boxShadow: [

          BoxShadow(

            color:
            Colors.black12,

            blurRadius: 10,

            offset:
            const Offset(0, 4),
          ),
        ],
      ),

      child: Row(

        children: [

          // =====================
          // RANK
          // =====================

          CircleAvatar(

            radius: 26,

            backgroundColor:
            rankColor,

            child: Text(

              "#$rank",

              style:
              const TextStyle(

                color: Colors.white,

                fontWeight:
                FontWeight.bold,

                fontSize: 18,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // =====================
          // PLAYER INFO
          // =====================

          Expanded(

            child: Column(

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                Text(

                  player.name,

                  style:
                  const TextStyle(

                    fontSize: 22,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                    height: 8),

                Text(
                  "👣 ${player.totalSteps} Steps",
                ),

                Text(
                  "🌍 ${player.totalLand} Land",
                ),

                Text(
                  "👥 ${player.team}",
                ),

                Text(
                  "⭐ Level ${player.level}",
                ),

                if (player.streakCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "🔥 ${player.streakCount} Day Streak",
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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