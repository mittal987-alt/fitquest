import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/team_request_model.dart';
import '../services/firebase_service.dart';
import '../controller/raid_controller.dart';
import '../widgets/team_card.dart';
import 'team_members_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final FirebaseService firebaseService = FirebaseService();
  Stream<PlayerModel?>? _playerStream;
  Stream<List<TeamModel>>? _teamsStream;

  static const Color _kPrimaryPurple = Color(0xFF8E2DE2);
  static const Color _kSecondaryPurple = Color(0xFF4A00E0);
  static const Color _kBgColor = Color(0xFF0D1117);
  static const Color _kSurfaceColor = Color(0xFF161B22);

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      _playerStream = firebaseService.getPlayerStream(currentUid);
    }
    _teamsStream = firebaseService.getTeams();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      return const Scaffold(backgroundColor: _kBgColor, body: Center(child: Text("NOT LOGGED IN", style: TextStyle(color: Colors.white))));
    }

    return StreamBuilder<PlayerModel?>(
      stream: _playerStream,
      builder: (context, playerSnapshot) {
        final currentPlayer = playerSnapshot.data;
        if (currentPlayer == null) return const Scaffold(backgroundColor: _kBgColor, body: Center(child: CircularProgressIndicator(color: _kPrimaryPurple)));

        final bool alreadyInTeam = currentPlayer.isInTeam;

        return Scaffold(
          backgroundColor: _kBgColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text("TEAM OPERATIONS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 18, color: Colors.white)),
            centerTitle: true,
          ),
          body: StreamBuilder<List<TeamModel>>(
            stream: _teamsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _kPrimaryPurple));
              }
              final teams = snapshot.data ?? [];

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  if (!alreadyInTeam)
                    SliverToBoxAdapter(child: _buildNoTeamState(currentPlayer))
                  else
                    SliverToBoxAdapter(
                      child: _buildInsideTeamDashboard(
                        teams.firstWhere((t) => t.id == currentPlayer.teamId, orElse: () => TeamModel(id: "", name: "Unknown", color: "purple", members: 1, maxMembers: 5, totalSteps: 0, leaderId: "", strongholdActive: false, logo: "")),
                        currentPlayer,
                      ),
                    ),
                  
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("AVAILABLE TEAMS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 1.5)),
                          Text("${teams.length} OPERATIONAL", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _kPrimaryPurple)),
                        ],
                      ),
                    ),
                  ),

                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final team = teams[index];
                        final isCurrent = team.id == currentPlayer.teamId;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: _buildEnhancedTeamCard(team, isCurrent, currentPlayer),
                        );
                      },
                      childCount: teams.length,
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNoTeamState(PlayerModel player) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _kSurfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _kPrimaryPurple.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.groups_outlined, color: _kPrimaryPurple, size: 40),
          ),
          const SizedBox(height: 24),
          const Text("YOU'RE NOT IN A TEAM", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          const Text(
            "Join forces with other operators to capture more territory and dominate the leaderboards.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _actionBtn("CREATE TEAM", _kPrimaryPurple, () => _showCreateTeamDialog(player))),
              const SizedBox(width: 12),
              Expanded(child: _actionBtn("JOIN BY CODE", Colors.white10, () => _showJoinCodeDialog(player))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
    );
  }

  Widget _buildInsideTeamDashboard(TeamModel team, PlayerModel player) {
    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTeamBanner(team),
          const SizedBox(height: 24),
          const Text("MISSION PROGRESS", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _buildTeamStatsGrid(team, player),
          const SizedBox(height: 24),
          _buildWeeklyChallenge(team),
          const SizedBox(height: 32),
          _buildTeamQuickActions(team),
        ],
      ),
    );
  }

  Widget _buildTeamBanner(TeamModel team) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kPrimaryPurple, _kSecondaryPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                Text("CAPTAIN ID: ${team.leaderId.substring(0, 8).toUpperCase()}", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
        ],
      ),
    );
  }

  Widget _buildTeamStatsGrid(TeamModel team, PlayerModel player) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _miniStatCard("WEEKLY STEPS", team.totalSteps.toString(), Icons.directions_walk_rounded),
        _miniStatCard("TERRITORY", "12.4 KM²", Icons.map_rounded),
        _miniStatCard("CONTRIBUTION", "${player.dailySteps} TODAY", Icons.add_chart_rounded),
        _miniStatCard("RANKING", "#4 GLOBAL", Icons.leaderboard_rounded),
      ],
    );
  }

  Widget _miniStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kSurfaceColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kPrimaryPurple, size: 16),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWeeklyChallenge(TeamModel team) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _kSurfaceColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("WEEKLY CHALLENGE", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Text("3D 12H REMAINING", style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text("COLLECTIVE 500K STEPS", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(value: 0.65, minHeight: 6, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation(Colors.orangeAccent)),
          ),
          const SizedBox(height: 8),
          const Text("325,412 / 500,000 STEPS", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTeamQuickActions(TeamModel team) {
    return Column(
      children: [
        _quickActionTile("TEAM CHAT", Icons.chat_bubble_outline_rounded, "COMMUNICATION CHANNEL COMING SOON"),
        const SizedBox(height: 12),
        _quickActionTile("INVITE FRIENDS", Icons.person_add_outlined, "EXPAND YOUR OPERATIONAL UNIT"),
        const SizedBox(height: 12),
        _quickActionTile("LEAVE TEAM", Icons.logout_rounded, "EXIT CURRENT SQUADRON", color: Colors.redAccent),
      ],
    );
  }

  Widget _quickActionTile(String title, IconData icon, String subtitle, {Color color = _kPrimaryPurple}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.1))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
              Text(subtitle, style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTeamCard(TeamModel team, bool isJoined, PlayerModel player) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isJoined ? _kPrimaryPurple.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _kPrimaryPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.motion_photos_on_rounded, color: _kPrimaryPurple, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _cardMeta(Icons.people_outline, "${team.members}/5"),
                    const SizedBox(width: 12),
                    _cardMeta(Icons.directions_walk_rounded, "${(team.totalSteps / 1000).toStringAsFixed(1)}K"),
                    const SizedBox(width: 12),
                    _cardMeta(Icons.map_rounded, "8.2 KM²"),
                  ],
                ),
              ],
            ),
          ),
          if (!isJoined)
            ElevatedButton(
              onPressed: () => _handleJoinTeam(team, player),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("JOIN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            )
          else
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24),
        ],
      ),
    );
  }

  Widget _cardMeta(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white24, size: 12),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Dialog placeholders
  void _showCreateTeamDialog(PlayerModel player) { /* Implementation */ }
  void _showJoinCodeDialog(PlayerModel player) { /* Implementation */ }
  Future<void> _handleJoinTeam(TeamModel team, PlayerModel player) async { /* Implementation */ }
}
