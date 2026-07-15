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
    if (currentUid == null) {
      return const Scaffold(
        body: Center(
          child: Text("NOT LOGGED IN", style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "RAID BOSS: THE COLOSSUS",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 15),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
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
            return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final team = TeamModel.fromMap(data);

          // FIX: was a hardcoded local `maxHp = 100000.0` that would silently
          // desync from the real boss health pool the moment GameplayRules
          // changed. Now sourced from the same constant every other raid
          // screen uses (RaidController, firebase_service.dart).
          final double maxHp = GameplayRules.colossusMaxHp;
          final double hp = team.raidBossHp.clamp(0.0, maxHp);
          final double hpPercent = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name.toUpperCase(),
                  style: const TextStyle(color: Colors.black45, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LinearProgressIndicator(
                    value: hpPercent,
                    minHeight: 22,
                    color: Colors.redAccent,
                    backgroundColor: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "${hp.toInt()} / ${maxHp.toInt()} HP",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87),
                ),
                if (team.strongholdActive) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      const Text(
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

                      final (success, defeated) =
                      await _service.executeTeamRaidAttack(currentUid, widget.teamId);

                      if (!mounted) return;
                      setState(() => _attacking = false);

                      if (!success) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text("INSUFFICIENT STAMINA OR ON COOLDOWN"),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text("ATTACK LANDED"),
                          backgroundColor: Colors.greenAccent,
                        ),
                      );

                      if (defeated && mounted) {
                        _showVictoryDialog(team);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.black.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: _attacking
                        ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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