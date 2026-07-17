import 'dart:async';
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
  String currentFilter = "SOLO"; // SOLO, MY_TEAM, ALL_TEAMS

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(
          child: Text(
            "User Not Logged In",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return StreamBuilder<PlayerModel?>(
      stream: firebaseService.getPlayerStream(user.uid),
      builder: (context, playerSnapshot) {
        if (playerSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1117),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF8E2DE2))),
          );
        }

        final currentPlayer = playerSnapshot.data;
        if (currentPlayer == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1117),
            body: Center(
              child: Text("Player Profiles Inaccessible", style: TextStyle(color: Colors.redAccent)),
            ),
          );
        }

        final String userTeam = currentPlayer.team;

        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              "LEADERBOARDS",
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5, fontSize: 18),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Column(
            children: [
              // TACTICAL FILTER SWITCH PANEL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      _buildFilterButton("SOLO", "SOLO", const Color(0xFF8E2DE2)),
                      if (currentPlayer.isInTeam) ...[
                        const SizedBox(width: 4),
                        _buildFilterButton("MY_TEAM", "MY TEAM", Colors.greenAccent),
                      ],
                      const SizedBox(width: 4),
                      _buildFilterButton("ALL_TEAMS", "TEAMS", Colors.cyanAccent),
                    ],
                  ),
                ),
              ),

              // DYNAMIC LEADERBOARD STREAMS LAYER
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: currentFilter == "SOLO"
                      ? _buildSoloStream()
                      : (currentFilter == "MY_TEAM" ? _buildTeamMembersStream(userTeam) : _buildGlobalTeamsStream()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // HELPER WIDGET FILTERS & STREAM SWITCHERS
  // ==========================================

  /// Throttles a stream to emit at most once every [duration].
  /// Prevents UI jitter during high-frequency Firestore updates.
  Stream<T> _throttleStream<T>(Stream<T> source, {Duration duration = const Duration(seconds: 15)}) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    Timer? timer;
    T? latestValue;
    bool hasValue = false;

    controller = StreamController<T>.broadcast(
      onListen: () {
        subscription = source.listen((value) {
          latestValue = value;
          hasValue = true;

          if (timer == null) {
            controller.add(value);
            timer = Timer(duration, () {
              timer = null;
              if (hasValue && latestValue != null) {
                controller.add(latestValue!);
              }
            });
          }
        }, onDone: () => controller.close(), onError: (e) => controller.addError(e));
      },
      onCancel: () {
        subscription?.cancel();
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  Widget _buildFilterButton(String filterTarget, String label, Color activeNeonColor) {
    final bool isActive = currentFilter == filterTarget;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => currentFilter = filterTarget),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    colors: [activeNeonColor, activeNeonColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white60,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSoloStream() {
    return StreamBuilder<List<PlayerModel>>(
      key: const ValueKey("SoloStream"),
      stream: _throttleStream(firebaseService.getLeaderboard()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF8E2DE2)));
        if (snapshot.hasError) return Center(child: Text("${snapshot.error}", style: const TextStyle(color: Colors.white60)));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No Players Found", style: TextStyle(color: Colors.white24)));

        final players = snapshot.data!;
        return Column(
          children: [
            _buildTopCard(
              title: "TOP GLOBAL PLAYER",
              name: players[0].name,
              value: "${players[0].totalSteps} Steps Logged",
              icon: Icons.emoji_events_rounded,
              neonColor: const Color(0xFF8E2DE2),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: players.length,
                itemBuilder: (context, index) => PlayerTile(player: players[index], rank: index + 1),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTeamMembersStream(String teamName) {
    return StreamBuilder<List<PlayerModel>>(
      key: const ValueKey("TeamMembersStream"),
      stream: _throttleStream(firebaseService.getTeamLeaderboard(teamName)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        if (snapshot.hasError) return Center(child: Text("${snapshot.error}", style: const TextStyle(color: Colors.white60)));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No Team Members Found", style: TextStyle(color: Colors.white24)));

        final players = snapshot.data!;
        return Column(
          children: [
            _buildTopCard(
              title: "TOP TEAM MEMBER",
              name: players[0].name,
              value: "${players[0].totalSteps} Steps Logged",
              icon: Icons.bolt_rounded,
              neonColor: Colors.greenAccent,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: players.length,
                itemBuilder: (context, index) => PlayerTile(player: players[index], rank: index + 1),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlobalTeamsStream() {
    return StreamBuilder<List<TeamModel>>(
      key: const ValueKey("GlobalTeamsStream"),
      stream: _throttleStream(firebaseService.getTeamLeaderboardGlobal()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        if (snapshot.hasError) return Center(child: Text("${snapshot.error}", style: const TextStyle(color: Colors.white60)));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No Teams Found", style: TextStyle(color: Colors.white24)));

        final teams = snapshot.data!;
        return Column(
          children: [
            _buildTopCard(
              title: "APEX EFFICIENCY TEAM",
              name: teams[0].name,
              value: "${teams[0].stepEfficiency.toStringAsFixed(0)} Avg Steps",
              icon: Icons.bolt_rounded,
              neonColor: Colors.cyanAccent,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: teams.length,
                itemBuilder: (context, index) {
                  final team = teams[index];
                  final double avgEfficiency = team.stepEfficiency;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: index == 0
                              ? Colors.amber.withValues(alpha: 0.1)
                              : const Color(0xFF0D1117),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: index == 0 ? Colors.amberAccent : Colors.white.withValues(alpha: 0.1),
                            width: index == 0 ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: index == 0
                              ? const Icon(Icons.emoji_events_rounded, color: Colors.amberAccent, size: 20)
                              : Text(
                            "${index + 1}",
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      title: Text(team.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "👥 ${team.members} members  •  ⚡ Efficiency: ${avgEfficiency.toStringAsFixed(0)} steps/member",
                          style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${team.totalSteps}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.cyanAccent),
                          ),
                          const Text("STEPS", style: TextStyle(fontSize: 9, color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
    );
  }

  Widget _buildTopCard({
    required String title,
    required String name,
    required String value,
    required IconData icon,
    required Color neonColor,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: neonColor.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: neonColor.withValues(alpha: 0.1),
            child: Icon(icon, size: 30, color: neonColor),
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(color: neonColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}