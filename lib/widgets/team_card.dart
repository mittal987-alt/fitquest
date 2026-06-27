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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
            backgroundColor: team.getTeamColor().withValues(alpha: 0.1),
            child: Icon(
              Icons.groups,
              color: team.getTeamColor(),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          // =====================
          // TEAM INFO
          // =====================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "👥 ${team.members} Members",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "🌍 ${team.totalLand} Land",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "👣 ${team.totalSteps} Steps",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // =====================
          // JOIN BUTTON
          // =====================
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: joined ? Colors.black.withValues(alpha: 0.05) : team.getTeamColor(),
              foregroundColor: joined ? Colors.black54 : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: joined ? null : onJoin,
            child: Text(
              joined ? "Joined" : "Join",
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      ),
    );
  }
}