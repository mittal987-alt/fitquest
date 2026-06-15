import 'package:flutter/material.dart';

import '../models/team_model.dart';

class TeamCard extends StatelessWidget {

  final TeamModel team;

  final bool joined;

  final VoidCallback? onJoin;
  final VoidCallback? onTap;

  const TeamCard({
    super.key,
    required this.team,
    required this.joined,
    this.onJoin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),

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
          // TEAM ICON
          // =====================

          CircleAvatar(

            radius: 30,

            backgroundColor:
            team.getTeamColor(),

            child: const Icon(

              Icons.groups,

              color: Colors.white,

              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          // =====================
          // TEAM INFO
          // =====================

          Expanded(

            child: Column(

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                Text(

                  team.name,

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
                  "👥 ${team.members} Members",
                ),

                Text(
                  "🌍 ${team.totalLand} Land",
                ),

                Text(
                  "👣 ${team.totalSteps} Steps",
                ),
              ],
            ),
          ),

          // =====================
          // JOIN BUTTON
          // =====================

          ElevatedButton(

            style:
            ElevatedButton.styleFrom(

              backgroundColor:
              joined
                  ? Colors.grey
                  : team.getTeamColor(),

              shape:
              RoundedRectangleBorder(

                borderRadius:
                BorderRadius.circular(
                    14),
              ),
            ),

            onPressed:
            joined
                ? null
                : onJoin,

            child: Text(

              joined
                  ? "Joined"
                  : "Join",
            ),
          ),
        ],
      ),
      ),
    );
  }
}