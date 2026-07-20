import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import '../../models/team_model.dart';
import '../../config/gameplay_rules.dart';
import 'raid_result_screen.dart';
import 'raid_history_screen.dart';
import '../../controller/raid_controller.dart';
import 'package:provider/provider.dart';

class RaidBossScreen extends StatefulWidget {
  final String teamId;

  const RaidBossScreen({super.key, required this.teamId});

  @override
  State<RaidBossScreen> createState() => _RaidBossScreenState();
}

class _RaidBossScreenState extends State<RaidBossScreen> {
  final FirebaseService _service = FirebaseService();
  bool _attacking = false;

  void _showVictoryDialog(TeamModel team) {
    final raidController = context.read<RaidController>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RaidResultScreen(
          participants: raidController.participants,
          teamName: team.name,
          totalDamage: raidController.bossMaxHp - raidController.bossCurrentHp,
          bossName: raidController.bossName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // FIX: was `FirebaseAuth.instance.currentUser!.uid` risk elsewhere in the
    // app — guarded consistently here too.
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final colorScheme = Theme.of(context).colorScheme;

    if (currentUid == null) {
      return Scaffold(
        body: Center(
          child: Text("NOT LOGGED IN", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection("teams").doc(widget.teamId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) return const Text("RAID BOSS");
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final team = TeamModel.fromMap(data);
            final bossConfig = GameplayRules.bossPool.firstWhere(
              (b) => b["id"] == team.raidBossId,
              orElse: () => GameplayRules.bossPool[0],
            );
            return Text(
              "RAID BOSS: ${bossConfig["name"]}",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 15, color: colorScheme.onSurface),
            );
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: "Mission Archives",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RaidHistoryScreen(teamId: widget.teamId)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("teams").doc(widget.teamId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: CircularProgressIndicator(color: colorScheme.primary));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final team = TeamModel.fromMap(data);

          final activeSynergies = team.synergyResonance.entries
              .where((e) => e.value.isAfter(DateTime.now()))
              .toList();

          final bossConfig = GameplayRules.bossPool.firstWhere(
            (b) => b["id"] == team.raidBossId,
            orElse: () => GameplayRules.bossPool[0],
          );

          final double maxHp = (bossConfig["maxHp"] as num).toDouble();
          final double hp = team.raidBossHp.clamp(0.0, maxHp);
          final double hpPercent = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
          final Color bossColor = Color(bossConfig["color"] as int);

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      team.name.toUpperCase(),
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: bossColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bossConfig["element"].toUpperCase(),
                        style: TextStyle(color: bossColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Text(
                        bossConfig["name"],
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: bossColor, letterSpacing: -1),
                      ),
                      Text(
                        "WEAKNESS: ${bossConfig["weakness"]}",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), letterSpacing: 1),
                      ),
                      if (activeSynergies.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          children: activeSynergies.map((e) {
                            final className = e.key;
                            Color synergyColor = colorScheme.secondary;
                            if (className == 'medic') synergyColor = Colors.greenAccent;
                            if (className == 'tank') synergyColor = Colors.blueAccent;
                            if (className == 'scout') synergyColor = Colors.orangeAccent;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: synergyColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: synergyColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome_rounded, size: 10, color: synergyColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${className.toUpperCase()} RESONANCE",
                                    style: TextStyle(color: synergyColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LinearProgressIndicator(
                    value: hpPercent,
                    minHeight: 22,
                    color: bossColor,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "${hp.toInt()} / ${maxHp.toInt()} HP",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
                ),

                if (team.strongholdActive) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        "TEAM STRONGHOLD ACTIVE (1.5x DAMAGE)",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 40),

                // FIX: this used to just call
                // `_service.contributeRaidDamage(teamId, 500.0)` — a flat,
                // hardcoded 500 damage with no stamina cost, no gear
                // multipliers, and no cooldown check. Now uses the same
                // authoritative attack path as team_screen.dart
                // (executeTeamRaidAttack), so damage/stamina/cooldown rules
                // are identical no matter which screen the player attacks
                // from, and the victory screen is driven by the real
                // "defeated" result instead of being guessed.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _attacking
                        ? null
                        : () async {
                      setState(() => _attacking = true);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);

                      final (success, defeated, primalSpirit) =
                      await _service.executeTeamRaidAttack(currentUid, widget.teamId);

                      if (!mounted) return;
                      setState(() => _attacking = false);

                      if (!success) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: const Text("INSUFFICIENT STAMINA OR ON COOLDOWN"),
                            backgroundColor: colorScheme.error,
                          ),
                        );
                        return;
                      }

                      if (primalSpirit) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: const Text("✨ PRIMAL SPIRIT ULTIMATE TRIGGERED! 3.0x DAMAGE! ✨"),
                            backgroundColor: colorScheme.tertiary,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      } else {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: const Text("ATTACK LANDED"),
                            backgroundColor: colorScheme.secondary,
                          ),
                        );
                      }

                      if (defeated && mounted) {
                        _showVictoryDialog(team);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: _attacking
                        ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onError),
                    )
                        : const Icon(Icons.bolt_rounded),
                    label: const Text(
                      "ATTACK (50 STAMINA)",
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ),

              ],
            ),
          );
        },
      ),
    );
  }
}