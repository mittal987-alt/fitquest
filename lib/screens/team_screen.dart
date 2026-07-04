import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_model.dart';
import '../models/team_request_model.dart';
import '../services/firebase_service.dart';
import '../widgets/team_card.dart';
import 'team_request_screen.dart';
import '../models/player_model.dart';
import 'team_members_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final FirebaseService firebaseService = FirebaseService();

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
              "SQUAD CHANNELS",
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
            label: const Text("FOUND NEW SQUAD", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white)),
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
                orElse: () => TeamModel(id: "", name: "No Team", color: "blue", members: 0, maxMembers: 50, totalLand: 0, totalSteps: 0, leaderId: "", strongholdActive: false, logo: ""),
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
                            "CURRENT OPERATIONAL UNIT",
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
                                  currentTeam.strongholdActive ? "STRONGHOLD ACTIVE (1.5x RAID DMG)" : "STRONGHOLD INACTIVE",
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
                            const Text(
                              "RAID BOSS HP",
                              style: TextStyle(color: Colors.black45, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: currentTeam.raidBossHp / 100000.0,
                                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                color: Colors.redAccent,
                                minHeight: 8,
                              ),
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
                                bool success = await firebaseService.executeTeamRaidAttack(currentUid, currentTeam.id);
                                if (!success) {
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text("RECHARGE PROTOCOL: INSUFFICIENT STAMINA OR COOLDOWN ACTIVE"),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                } else {
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text("RAID KINETIC STRIKE CONFIRMED"),
                                      backgroundColor: Colors.greenAccent,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.bolt_rounded, size: 18),
                              label: const Text("EXECUTE RAID ATTACK", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ),
                            const SizedBox(height: 12),
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
                                        content: Text("COOLDOWN INJECTED: WAIT $hoursLeft HOURS TO TRANSIT"),
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
                                    title: const Text("TERMINATE LINK", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18)),
                                    content: Text("Sever connection vectors with ${currentTeam.name.toUpperCase()}?", style: const TextStyle(color: Colors.black54)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text("ABORT", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text("SEVER LINK", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ) ?? false;

                                if (confirm) {
                                  await firebaseService.leaveTeam(uid: currentUid, teamId: currentTeam.id);
                                }
                              },
                              icon: const Icon(Icons.link_off_rounded, size: 16),
                              label: const Text("SEVER SQUAD CONNECTION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "AVAILABLE COHORT SECTORS",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black45, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    ...teams.map((team) {
                      final isLeader = currentUid == team.leaderId;

                      return Column(
                        children: [
                          TeamCard(
                            team: team,
                            joined: selectedTeam == team.name,
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
                                      content: Text("ACTION LOCKOUT: TIME CONTEXT RESTRAINED BY $hoursLeft HOURS"),
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
                                    content: Text("CRITICAL OVERFLOW: TARGET SECTOR CAPACITY EXCEEDED"),
                                  ),
                                );
                                return;
                              }

                              final user = FirebaseAuth.instance.currentUser!;
                              TeamRequestModel request = TeamRequestModel(
                                requestId: DateTime.now().millisecondsSinceEpoch.toString(),
                                playerId: user.uid,
                                playerName: user.email ?? "Anonymous Node",
                                teamId: team.id,
                                teamName: team.name,
                                status: "pending",
                              );

                              await firebaseService.sendJoinRequest(request);

                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                                  content: Text("HANDSHAKE BROADCAST DISPATCHED TO ${team.name.toUpperCase()}", style: const TextStyle(color: Colors.greenAccent)),
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
                                  label: const Text("DECRYPT HANDSHAKE REQUESTS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
            "INITIALIZE NEW SQUAD NODE",
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Assign alpha identifier string for the squad", style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: "SQUAD_NAME",
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
              child: const Text("ABORT", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)),
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
                        content: Text("COOLDOWN ACTIVE: INITIALIZATION HALTED FOR $hoursLeft HOURS"),
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
                    totalLand: 0,
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
                      content: Text("SQUAD COMPILING COMPLETED: ${team.name.toUpperCase()} RECRUITING NOW"),
                      backgroundColor: Colors.greenAccent.withValues(alpha: 0.8),
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text("EMPTY PARAMETER: SPECIFY SQUAD IDENTIFIER"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text("INSTANTIATE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
