import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../services/firebase_service.dart';

class TeamMembersScreen extends StatelessWidget {
  final TeamModel team;

  const TeamMembersScreen({
    super.key,
    required this.team,
  });

  Widget _buildStatBar({required IconData icon, required Color color, required double value, required String label, required String displayValue, required ColorScheme colorScheme}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
                fontFamily: 'Courier',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.01, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statMini(IconData icon, String value, String label, Color color, ColorScheme colorScheme) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.3),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      final colorScheme = Theme.of(context).colorScheme;
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Text(
            "NOT LOGGED IN",
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    final bool isLeader = currentUid == team.leaderId;
    final FirebaseService firebaseService = FirebaseService();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "${team.name.toUpperCase()} ROSTER",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 16,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("players")
            .where("teamId", isEqualTo: team.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: team.getTeamColor(context)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "NO SQUAD UNITS FOUND",
                style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4), fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            );
          }

          List<PlayerModel> members = snapshot.data!.docs.map((doc) {
            return PlayerModel.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();

          members.sort((a, b) => b.totalSteps.compareTo(a.totalSteps));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final player = members[index];
              final bool playerIsLeader = player.uid == team.leaderId;

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: playerIsLeader
                        ? colorScheme.tertiary.withValues(alpha: 0.4)
                        : colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: playerIsLeader ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Column(
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: (playerIsLeader ? colorScheme.tertiary : colorScheme.primary).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: playerIsLeader ? colorScheme.tertiary : colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                  child: player.avatar.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(30),
                                          child: Image.network(player.avatar, fit: BoxFit.cover),
                                        )
                                      : Center(
                                          child: Text(
                                            player.name[0].toUpperCase(),
                                            style: TextStyle(
                                              color: playerIsLeader ? colorScheme.tertiary : colorScheme.primary,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: colorScheme.outlineVariant),
                                    ),
                                    child: Text(
                                      "${index + 1}",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player.name.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: colorScheme.onSurface,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    firebaseService.getRankTitle(player.level),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: colorScheme.primary.withValues(alpha: 0.6),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (playerIsLeader)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  "COMMANDER",
                                  style: TextStyle(color: colorScheme.tertiary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Body Section
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            _buildStatBar(
                              icon: Icons.flash_on_rounded,
                              color: Colors.pinkAccent,
                              value: player.maxStamina > 0 ? player.currentStamina / player.maxStamina : 0,
                              label: "STAMINA POOL",
                              displayValue: "${player.currentStamina} AP",
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 16),
                            _buildStatBar(
                              icon: Icons.track_changes_rounded,
                              color: Colors.purpleAccent,
                              value: player.dailyStepTarget > 0 ? player.dailySteps / player.dailyStepTarget : 0,
                              label: "DAILY OBJECTIVE",
                              displayValue: "${player.dailySteps} / ${player.dailyStepTarget}",
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 16),
                            _buildStatBar(
                              icon: Icons.auto_awesome_rounded,
                              color: Colors.cyanAccent,
                              value: (player.xp % 1000) / 1000,
                              label: "LEVEL PROGRESS",
                              displayValue: "${player.xp % 1000} / 1000 XP",
                              colorScheme: colorScheme,
                            ),
                            const SizedBox(height: 32),
                            
                            // Stats Grid
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _statMini(Icons.bolt_rounded, "${player.totalSteps}", "Total", Colors.amberAccent, colorScheme),
                                _statMini(Icons.local_fire_department_rounded, "${player.dailySteps}", "Today", Colors.redAccent, colorScheme),
                                _statMini(Icons.stars_rounded, "${player.level}", "Level", Colors.cyanAccent, colorScheme),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _statMini(Icons.handshake_rounded, "${player.trustScore}", "Trust", Colors.greenAccent, colorScheme),
                                _statMini(Icons.whatshot_rounded, "${player.streakCount}", "Streak", Colors.orangeAccent, colorScheme),
                                _statMini(Icons.shield_rounded, "${player.totalRaidDamage}", "Dmg", Colors.pinkAccent, colorScheme),
                              ],
                            ),

                            if (player.characterClass != null) ...[
                              const SizedBox(height: 32),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: colorScheme.outlineVariant),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      player.characterClass!.toUpperCase(),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: colorScheme.primary, letterSpacing: 2),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "STR ${player.strength}  |  AGI ${player.agility}  |  END ${player.endurance}",
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.onSurfaceVariant, letterSpacing: 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (player.hourlySteps.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "TELEMETRY LOGS (24H)",
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  Icon(Icons.analytics_outlined, size: 14, color: colorScheme.primary.withValues(alpha: 0.4)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 80,
                                child: LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(show: false),
                                    titlesData: const FlTitlesData(show: false),
                                    borderData: FlBorderData(show: false),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: player.hourlySteps.entries
                                            .map((e) => FlSpot(double.tryParse(e.key) ?? 0, e.value.toDouble()))
                                            .toList()
                                          ..sort((a, b) => a.x.compareTo(b.x)),
                                        isCurved: true,
                                        color: colorScheme.primary,
                                        barWidth: 4,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            colors: [
                                              colorScheme.primary.withValues(alpha: 0.2),
                                              colorScheme.primary.withValues(alpha: 0.0),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      if (isLeader && !playerIsLeader)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.error.withValues(alpha: 0.1),
                                foregroundColor: colorScheme.error,
                                elevation: 0,
                                side: BorderSide(color: colorScheme.error.withValues(alpha: 0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () async {
                                final bool confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: colorScheme.surfaceContainer,
                                    title: Text("CONFIRM TERMINATION", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16)),
                                    content: Text("Are you sure you want to purge ${player.name.toUpperCase()} from the squadron?", style: TextStyle(color: colorScheme.onSurfaceVariant)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text("CANCEL")),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: Text("PURGE", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ) ?? false;

                                if (confirmed) {
                                  await firebaseService.kickPlayer(playerId: player.uid, teamId: team.id);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("OPERATOR PURGED")),
                                  );
                                }
                              },
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                              label: const Text(
                                "TERMINATE CONTRACT",
                                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}