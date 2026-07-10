import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_model.dart';
import '../models/team_request_model.dart';
import '../services/firebase_service.dart';
import '../widgets/team_card.dart';
import 'team_request_screen.dart';
import '../models/player_model.dart';
import 'team_members_screen.dart';
import 'tactical_relay_screen.dart';

import 'package:provider/provider.dart';
import '../controller/raid_controller.dart';
import '../widgets/tactical_ping_feed.dart';
import '../features/raid/raid_result_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final FirebaseService firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _initializeRaidSync();
  }

  void _initializeRaidSync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final player = await firebaseService.getPlayer(user.uid);
      if (player != null && player.teamId != null && mounted) {
        context.read<RaidController>().initTeamRaid(player.teamId!);
      }
    }
  }

  void _showVictoryDialog(BuildContext context, String teamName) {
    final raidController = context.read<RaidController>();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RaidResultScreen(
          participants: raidController.participants,
          teamName: teamName,
          totalDamage: raidController.bossMaxHp - raidController.bossCurrentHp,
          bossName: raidController.bossName,
        ),
      ),
    );
  }

  Widget _rewardItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<PlayerModel?>(
      stream: firebaseService.getPlayerStream(currentUid),
      builder: (context, playerSnapshot) {
        final currentPlayer = playerSnapshot.data;
        final String selectedTeam = currentPlayer?.team ?? "No Team";
        final bool alreadyInTeam = currentPlayer?.isInTeam ?? false;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              "TEAMS",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
          floatingActionButton: alreadyInTeam
              ? null
              : FloatingActionButton.extended(
            backgroundColor: Colors.blueAccent,
            elevation: 2,
            onPressed: () => showCreateTeamDialog(currentPlayer),
            icon: const Icon(Icons.add_moderator_rounded, color: Colors.white),
            label: const Text("CREATE NEW TEAM", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white)),
          ),
          body: StreamBuilder<List<TeamModel>>(
            stream: firebaseService.getTeams(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    "NO NETWORK SQUADS INSTANTIATED",
                    style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold),
                  ),
                );
              }

              final teams = snapshot.data!;
              final currentTeam = teams.firstWhere(
                    (t) => t.id == currentPlayer?.teamId,
                orElse: () => TeamModel(id: "", name: "No Team", color: "blue", members: 0, maxMembers: 50, totalSteps: 0, leaderId: "", strongholdActive: false, logo: ""),
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP PROFILE NODE SQUAD BANNER
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CURRENT TEAM",
                            style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedTeam.toUpperCase(),
                            style: const TextStyle(color: Colors.black87, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          if (alreadyInTeam && currentTeam.id.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 16,
                                  color: currentTeam.strongholdActive ? Colors.amber : Colors.black26,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  currentTeam.strongholdActive ? "TEAM BUFF ACTIVE (1.5x BOSS DMG)" : "TEAM BUFF INACTIVE",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: currentTeam.strongholdActive ? Colors.amber : Colors.black38,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                TeamStat(title: "Steps", value: currentTeam.totalSteps.toString()),
                                TeamStat(title: "Boss Dmg", value: currentTeam.totalRaidDamage.toInt().toString()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "BOSS HEALTH",
                              style: TextStyle(color: Colors.black45, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 6),
                            Consumer<RaidController>(
                              builder: (context, raidController, child) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: raidController.bossHpPercentage,
                                        backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                        color: Colors.redAccent,
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${raidController.bossCurrentHp.toInt()} / ${raidController.bossMaxHp.toInt()} HP",
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orangeAccent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onPressed: () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  // ENERGY BOOST BONUS
                                  double energyBoostMult = 1.0;
                                  if (currentPlayer?.activePowerUps.containsKey("energy_boost") == true) {
                                    DateTime expiry = currentPlayer!.activePowerUps["energy_boost"]!;
                                    if (expiry.isAfter(DateTime.now())) {
                                      energyBoostMult = currentPlayer.energyBoostRaidMultiplier;
                                    }
                                  }

                                  double totalDmg = ((currentPlayer?.effectiveStrength ?? 10) + (currentPlayer?.effectiveAgility ?? 10)) * 1.0 * (currentTeam.strongholdActive ? 1.5 : 1.0) * energyBoostMult;

                                  bool success = await firebaseService.executeTeamRaidAttack(currentUid, currentTeam.id);
                                if (!success) {
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text("INSUFFICIENT STAMINA OR ON COOLDOWN"),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                } else {
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text("BOSS ATTACK SUCCESSFUL"),
                                      backgroundColor: Colors.greenAccent,
                                    ),
                                  );
                                  
                                  // TRIGGER TACTICAL PING FOR DAMAGE
                                  await firebaseService.sendTacticalPing(
                                    currentTeam.id, 
                                    "FRONT_LINE", 
                                    "${currentPlayer?.name.toUpperCase()} ATTACKED THE BOSS"
                                  );

                                  if (context.mounted && currentTeam.raidBossHp - totalDmg <= 0) {
                                    _showVictoryDialog(context, currentTeam.name);
                                  }
                                }
                              },
                              icon: const Icon(Icons.bolt_rounded, size: 18),
                              label: const Text("ATTACK BOSS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TacticalRelayScreen(
                                      teamId: currentTeam.id,
                                      teamName: currentTeam.name,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.sync_alt_rounded, size: 18),
                              label: const Text("TACTICAL RELAY", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ),
                            const SizedBox(height: 12),
                            const TacticalPingFeed(),
                            const SizedBox(height: 12),
                            if (currentUid == currentTeam.leaderId) ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(alpha: 0.1),
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                  side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onPressed: () async {
                                  bool confirm = await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      title: const Text("DISBAND TEAM", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18)),
                                      content: const Text("Permanently dissolve this team? This action is irreversible."),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text("CANCEL", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text("DISBAND", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ) ?? false;

                                  if (confirm) {
                                    await firebaseService.deleteTeam(currentTeam.id);
                                  }
                                },
                                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                                label: const Text("DISBAND TEAM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                              ),
                            ] else ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                  foregroundColor: Colors.redAccent,
                                  elevation: 0,
                                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onPressed: () async {
                                  if (currentPlayer?.lastTeamAction != null) {
                                    final diff = DateTime.now().difference(currentPlayer!.lastTeamAction!);
                                    if (diff.inHours < 24) {
                                      final hoursLeft = 24 - diff.inHours;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("PLEASE WAIT $hoursLeft HOURS TO LEAVE"),
                                          backgroundColor: Colors.orangeAccent,
                                        ),
                                      );
                                      return;
                                    }
                                  }

                                  bool confirm = await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      title: const Text("LEAVE TEAM", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18)),
                                      content: Text("Leave ${currentTeam.name.toUpperCase()}?", style: const TextStyle(color: Colors.black54)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text("CANCEL", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text("LEAVE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ) ?? false;

                                  if (confirm) {
                                    await firebaseService.leaveTeam(uid: currentUid, teamId: currentTeam.id);
                                  }
                                },
                                icon: const Icon(Icons.link_off_rounded, size: 16),
                                label: const Text("LEAVE TEAM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "AVAILABLE TEAMS",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black45, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    ...teams.map((team) {
                      final isLeader = currentUid == team.leaderId;
                      final isCurrentTeam = currentPlayer?.teamId == team.id;

                      return Column(
                        children: [
                          TeamCard(
                            team: team,
                            joined: isCurrentTeam,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TeamMembersScreen(
                                    teamName: team.name,
                                    teamId: team.id,
                                    leaderId: team.leaderId,
                                  ),
                                ),
                              );
                            },
                            onJoin: () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              if (currentPlayer?.lastTeamAction != null) {
                                final diff = DateTime.now().difference(currentPlayer!.lastTeamAction!);
                                if (diff.inHours < 24) {
                                  final hoursLeft = 24 - diff.inHours;
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text("WAIT $hoursLeft HOURS BEFORE JOINING A NEW TEAM"),
                                      backgroundColor: Colors.orangeAccent,
                                    ),
                                  );
                                  return;
                                }
                              }

                              if (team.members >= team.maxMembers) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Colors.redAccent,
                                    content: Text("TEAM IS FULL"),
                                  ),
                                );
                                return;
                              }

                              final user = FirebaseAuth.instance.currentUser!;
                              TeamRequestModel request = TeamRequestModel(
                                requestId: DateTime.now().millisecondsSinceEpoch.toString(),
                                playerId: user.uid,
                                playerName: user.email ?? "Anonymous Player",
                                teamId: team.id,
                                teamName: team.name,
                                status: "pending",
                              );

                              await firebaseService.sendJoinRequest(request);

                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                                  content: Text("JOIN REQUEST SENT TO ${team.name.toUpperCase()}", style: const TextStyle(color: Colors.greenAccent)),
                                ),
                              );
                            },
                          ),
                          if (isLeader)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 8),
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TeamRequestsScreen(
                                          teamId: team.id,
                                          teamName: team.name,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.satellite_alt_rounded, size: 16),
                                  label: const Text("VIEW JOIN REQUESTS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void showCreateTeamDialog(PlayerModel? currentPlayer) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            "CREATE NEW TEAM",
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Assign a name for your team", style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: "TEAM NAME",
                  hintStyle: const TextStyle(color: Colors.black26),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("CANCEL", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                if (currentPlayer?.lastTeamAction != null) {
                  final diff = DateTime.now().difference(currentPlayer!.lastTeamAction!);
                  if (diff.inHours < 24) {
                    final hoursLeft = 24 - diff.inHours;
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text("PLEASE WAIT $hoursLeft HOURS BEFORE CREATING A TEAM"),
                        backgroundColor: Colors.orangeAccent,
                      ),
                    );
                    return;
                  }
                }

                if (controller.text.trim().isNotEmpty) {
                  TeamModel team = TeamModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: controller.text.trim(),
                    color: "purple",
                    members: 1,
                    maxMembers: 50,
                    totalSteps: 0,
                    leaderId: FirebaseAuth.instance.currentUser!.uid,
                    strongholdActive: false,
                    logo: "",
                  );

                  await firebaseService.createTeam(team);

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text("TEAM ${team.name.toUpperCase()} CREATED"),
                      backgroundColor: Colors.greenAccent.withValues(alpha: 0.8),
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text("PLEASE SPECIFY A TEAM NAME"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text("CREATE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

class TeamStat extends StatelessWidget {
  final String title;
  final String value;

  const TeamStat({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          title.toUpperCase(),
          style: const TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
