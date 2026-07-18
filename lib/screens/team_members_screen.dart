import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/player_model.dart';
import '../models/gear_model.dart';
import '../services/firebase_service.dart';

class TeamMembersScreen extends StatelessWidget {
  final String teamName;
  final String teamId;
  final String leaderId;

  const TeamMembersScreen({
    super.key,
    required this.teamName,
    required this.teamId,
    required this.leaderId,
  });

  Widget _buildStatBar({required IconData icon, required Color color, required double value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color.withValues(alpha: 0.8), letterSpacing: 0.5)),
              ],
            ),
            Text("${(value * 100).toInt()}%", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.1),
            color: color,
            minHeight: 3,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(
          child: Text(
            "NOT LOGGED IN",
            style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    final bool isLeader = currentUid == leaderId;
    final FirebaseService firebaseService = FirebaseService();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "${teamName.toUpperCase()} ROSTER",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("players")
            .where("teamId", isEqualTo: teamId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF8E2DE2)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "NO SQUAD UNITS FOUND",
                style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1),
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
              final bool playerIsLeader = player.uid == leaderId;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: playerIsLeader
                        ? Colors.orangeAccent.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                    width: playerIsLeader ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: playerIsLeader
                                ? Colors.orangeAccent.withValues(alpha: 0.1)
                                : const Color(0xFF8E2DE2).withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: playerIsLeader ? Colors.orangeAccent : const Color(0xFF8E2DE2).withValues(alpha: 0.4),
                            ),
                          ),
                          child: player.avatar.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.network(
                              player.avatar,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(
                                  "#${index + 1}",
                                  style: TextStyle(
                                    color: playerIsLeader ? Colors.orangeAccent : const Color(0xFF8E2DE2),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          )
                              : Center(
                            child: Text(
                              "#${index + 1}",
                              style: TextStyle(
                                color: playerIsLeader ? Colors.orangeAccent : const Color(0xFF8E2DE2),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      player.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (playerIsLeader) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orangeAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                                      ),
                                      child: const Text(
                                        "COMMANDER",
                                        style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  if (player.activePowerUps.containsKey('energy_boost') &&
                                      player.activePowerUps['energy_boost']!.isAfter(DateTime.now()))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.bolt, color: Colors.greenAccent, size: 10),
                                          SizedBox(width: 2),
                                          Text(
                                            "ENERGIZED",
                                            style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.w900),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildStatBar(
                                icon: Icons.battery_charging_full,
                                color: const Color(0xFF8E2DE2),
                                value: player.maxStamina > 0 ? player.currentStamina / player.maxStamina : 0,
                                label: "STAMINA POOL",
                              ),
                              const SizedBox(height: 6),
                              _buildStatBar(
                                icon: Icons.directions_run,
                                color: Colors.orangeAccent,
                                value: player.dailyStepTarget > 0 ? player.dailySteps / player.dailyStepTarget : 0,
                                label: "DAILY STEP GOAL",
                              ),
                              const SizedBox(height: 6),
                              _buildStatBar(
                                icon: Icons.star,
                                color: Colors.cyanAccent,
                                value: (player.xp % 1000) / 1000,
                                label: "LEVEL PROGRESS",
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    "⚡ ${player.totalSteps} TOTAL",
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "🔥 ${player.dailySteps} TODAY",
                                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "⭐ LVL ${player.level}",
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text(
                                    "🤝 ",
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    "${player.trustScore} TRUST",
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "🔥 ",
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    "${player.streakCount} STREAK",
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "💥 ",
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    "${player.totalRaidDamage} DMG",
                                    style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (player.characterClass != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        player.characterClass!.toUpperCase(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white70),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "STR ${player.strength} | AGI ${player.agility} | END ${player.endurance}",
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (player.equippedGear.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  children: player.equippedGear.entries.map((entry) {
                                    final gear = allGear.firstWhere((g) => g.id == entry.value, orElse: () => GearModel(id: '', name: 'Unknown', description: '', slot: GearSlot.footwear, modifiers: {}, price: 0, icon: ''));
                                    if (gear.id.isEmpty) return const SizedBox.shrink();
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8E2DE2).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFF8E2DE2).withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.shield_outlined, size: 8, color: Color(0xFF8E2DE2)),
                                          const SizedBox(width: 2),
                                          Text(
                                            gear.name.toUpperCase(),
                                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF8E2DE2)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              if (player.hourlySteps.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  "HOURLY STEP DATA (PERSONAL BESTS)",
                                  style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 80,
                                  width: double.infinity,
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
                                          color: const Color(0xFF8E2DE2).withValues(alpha: 0.5),
                                          barWidth: 2,
                                          isStrokeCapRound: true,
                                          dotData: const FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: const Color(0xFF8E2DE2).withValues(alpha: 0.1),
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
                      ],
                    ),
                    if (isLeader && !playerIsLeader) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                            foregroundColor: Colors.redAccent,
                            elevation: 0,
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            final bool confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF161B22),
                                title: const Text("CONFIRM TERMINATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                                content: Text("Are you sure you want to purge ${player.name.toUpperCase()} from the squadron?", style: const TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white38))),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text("PURGE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ) ?? false;

                            if (confirmed) {
                              await firebaseService.kickPlayer(playerId: player.uid, teamId: teamId);

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF161B22),
                                  content: Text("TERMINATED: OPERATOR PURGED FROM SQUAD", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
                          label: const Text(
                            "KICK OPERATOR",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
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