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
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: const Text("Teams"),
            centerTitle: true,
          ),
          floatingActionButton: alreadyInTeam
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: Colors.blue,
                  onPressed: () {
                    showCreateTeamDialog(currentPlayer);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Create Team"),
                ),
          body: StreamBuilder<List<TeamModel>>(
            stream: firebaseService.getTeams(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No Teams Found"));
              }

              final teams = snapshot.data!;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.lightBlue],
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Your Team",
                            style: TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            selectedTeam,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (alreadyInTeam)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  final team = teams.firstWhere(
                                      (t) => t.name == selectedTeam,
                                      orElse: () => TeamModel(
                                          id: "",
                                          name: "Unknown",
                                          color: "blue",
                                          members: 0,
                                          maxMembers: 50,
                                          totalLand: 0,
                                          totalSteps: 0,
                                          leaderId: "",
                                          logo: ""));

                                  if (team.id.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Team not found")),
                                    );
                                    return;
                                  }

                                  if (currentPlayer != null &&
                                      currentPlayer.lastTeamAction != null) {
                                    final diff = DateTime.now()
                                        .difference(currentPlayer.lastTeamAction!);
                                    if (diff.inHours < 24) {
                                      final hoursLeft = 24 - diff.inHours;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              "You must wait $hoursLeft more hours before changing teams."),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }
                                  }

                                  bool confirm = await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("Leave Team"),
                                          content: Text(
                                              "Are you sure you want to leave ${team.name}?"),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text("Cancel"),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text("Leave",
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;

                                  if (confirm) {
                                    await firebaseService.leaveTeam(
                                      uid: currentUid,
                                      teamId: team.id,
                                    );
                                  }
                                },
                                child: const Text("Leave Team"),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "All Teams",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
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
                              if (currentPlayer != null &&
                                  currentPlayer.lastTeamAction != null) {
                                final diff = DateTime.now()
                                    .difference(currentPlayer.lastTeamAction!);
                                if (diff.inHours < 24) {
                                  final hoursLeft = 24 - diff.inHours;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          "You must wait $hoursLeft more hours before performing another team action."),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }
                              }

                              if (team.members >= team.maxMembers) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text("Team is Full"),
                                  ),
                                );
                                return;
                              }

                              final user = FirebaseAuth.instance.currentUser!;
                              TeamRequestModel request = TeamRequestModel(
                                requestId: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                playerId: user.uid,
                                playerName: user.email ?? "Player",
                                teamId: team.id,
                                teamName: team.name,
                                status: "pending",
                              );

                              await firebaseService.sendJoinRequest(request);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.green,
                                    content: Text(
                                        "Request sent to ${team.name}"),
                                  ),
                                );
                              }
                            },
                          ),
                          if (isLeader)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
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
                                icon: const Icon(Icons.notifications),
                                label: const Text("View Requests"),
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
      builder: (context) {
        return AlertDialog(
          title: const Text("Create Team"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Enter team name",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (currentPlayer != null &&
                    currentPlayer.lastTeamAction != null) {
                  final diff = DateTime.now()
                      .difference(currentPlayer.lastTeamAction!);
                  if (diff.inHours < 24) {
                    final hoursLeft = 24 - diff.inHours;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "You must wait $hoursLeft more hours before creating a team."),
                        backgroundColor: Colors.orange,
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
                    logo: "",
                  );

                  await firebaseService.createTeam(team);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Team '${team.name}' created!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter a team name"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Create"),
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
