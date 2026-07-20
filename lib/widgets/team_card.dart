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
    final Color teamColor = team.getTeamColor(context);
    
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: joined ? teamColor.withValues(alpha: 0.3) : colorScheme.onSurface.withValues(alpha: 0.05),
            width: joined ? 2 : 1,
          ),
          boxShadow: [
            if (joined)
              BoxShadow(
                color: teamColor.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: teamColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.groups_rounded,
                color: teamColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        "${team.members}/${team.maxMembers}",
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.bolt_rounded, size: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        "${team.totalSteps} XP",
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!joined)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: teamColor.withValues(alpha: 0.1),
                  foregroundColor: teamColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: teamColor.withValues(alpha: 0.3)),
                  ),
                ),
                onPressed: onJoin,
                child: const Text(
                  "JOIN",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: teamColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "ACTIVE",
                  style: TextStyle(
                    color: teamColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
