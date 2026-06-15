import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../services/firebase_service.dart';
import '../widgets/player_tile.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final FirebaseService firebaseService = FirebaseService();

  bool showSolo = true;
  String currentFilter = "SOLO"; // SOLO, MY_TEAM, ALL_TEAMS

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<PlayerModel?>(
      stream: firebaseService.getPlayerStream(uid),
      builder: (context, playerSnapshot) {
        if (playerSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final currentPlayer = playerSnapshot.data;
        if (currentPlayer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Leaderboard")),
            body: const Center(child: Text("Player not found")),
          );
        }

        final String userTeam = currentPlayer.team;

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: const Text("Leaderboard"),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              currentFilter == "SOLO" ? Colors.orange : Colors.grey.shade300,
                        ),
                        onPressed: () {
                          setState(() {
                            currentFilter = "SOLO";
                            showSolo = true;
                          });
                        },
                        child: const Text("SOLO"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (currentPlayer.isInTeam) ...[
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                currentFilter == "MY_TEAM" ? Colors.green : Colors.grey.shade300,
                          ),
                          onPressed: () {
                            setState(() {
                              currentFilter = "MY_TEAM";
                              showSolo = false;
                            });
                          },
                          child: const Text("MY TEAM"),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              currentFilter == "ALL_TEAMS" ? Colors.blue : Colors.grey.shade300,
                        ),
                        onPressed: () {
                          setState(() {
                            currentFilter = "ALL_TEAMS";
                            showSolo = false;
                          });
                        },
                        child: const Text("TEAMS"),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: currentFilter == "SOLO"
                    ? StreamBuilder<List<PlayerModel>>(
                        stream: firebaseService.getLeaderboard(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text(snapshot.error.toString()));
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text("No Players Found"));
                          }
                          final players = snapshot.data!;
                          return Column(
                            children: [
                              _buildTopCard(
                                title: "Top Global Walker",
                                name: players[0].name,
                                value: "${players[0].totalSteps} Steps",
                                icon: Icons.emoji_events,
                                colors: [Colors.orange, Colors.deepOrange],
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: players.length,
                                  itemBuilder: (context, index) {
                                    return PlayerTile(
                                      player: players[index],
                                      rank: index + 1,
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : (currentFilter == "MY_TEAM"
                        ? StreamBuilder<List<PlayerModel>>(
                            stream: firebaseService.getTeamLeaderboard(userTeam),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return Center(child: Text(snapshot.error.toString()));
                              }
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(child: Text("No Members Found"));
                              }
                              final players = snapshot.data!;
                              return Column(
                                children: [
                                  _buildTopCard(
                                    title: "Top Team Walker",
                                    name: players[0].name,
                                    value: "${players[0].totalSteps} Steps",
                                    icon: Icons.person,
                                    colors: [Colors.green, Colors.teal],
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: players.length,
                                      itemBuilder: (context, index) {
                                        return PlayerTile(
                                          player: players[index],
                                          rank: index + 1,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        : StreamBuilder<List<TeamModel>>(
                            stream: firebaseService.getTeamLeaderboardGlobal(),
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
                              return Column(
                                children: [
                                  _buildTopCard(
                                    title: "Top Global Team",
                                    name: teams[0].name,
                                    value: "${teams[0].totalSteps} Total Steps",
                                    icon: Icons.groups,
                                    colors: [Colors.blue, Colors.indigo],
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: teams.length,
                                      itemBuilder: (context, index) {
                                        final team = teams[index];
                                        return Card(
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20)),
                                          elevation: 4,
                                          shadowColor: Colors.black26,
                                          margin: const EdgeInsets.only(bottom: 16),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.all(12),
                                            leading: Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: index == 0
                                                      ? [Colors.amber, Colors.orange]
                                                      : index == 1
                                                          ? [Colors.grey.shade300, Colors.grey.shade500]
                                                          : index == 2
                                                              ? [Colors.brown.shade200, Colors.brown.shade400]
                                                              : [team.getTeamColor().withValues(alpha: 0.7), team.getTeamColor()],
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: index < 3
                                                    ? Icon(
                                                        index == 0
                                                            ? Icons.emoji_events
                                                            : Icons.workspace_premium,
                                                        color: Colors.white,
                                                        size: 28,
                                                      )
                                                    : Text(
                                                        "${index + 1}",
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold),
                                                      ),
                                              ),
                                            ),
                                            title: Text(team.name,
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold)),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text(
                                                  "👥 ${team.members} members • 🌍 ${team.totalLand} Land",
                                                  style: TextStyle(color: Colors.grey.shade600),
                                                ),
                                                Text(
                                                  "⚡ Efficiency: ${(team.totalSteps / (team.members > 0 ? team.members : 1)).toStringAsFixed(0)} steps/member",
                                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  "${team.totalSteps}",
                                                  style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue),
                                                ),
                                                const Text(
                                                  "Steps",
                                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          )),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopCard({
    required String title,
    required String name,
    required String value,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Icon(icon, size: 60, color: Colors.white),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
    );
  }
}
