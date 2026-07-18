import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/team_request_model.dart';
import '../models/team_challenge_model.dart';
import '../models/activity_feed_model.dart';
import '../services/firebase_service.dart';
import '../widgets/team_card.dart';
import 'team_members_screen.dart';
import 'team_chat_screen.dart';
import 'team_achievements_screen.dart';
import 'team_shop_screen.dart';

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
      _ensureDailyChallenge(currentUid);
      _setupNotificationListener(currentUid);
    }
    _teamsStream = firebaseService.getTeams();
  }

  void _setupNotificationListener(String uid) async {
    final player = await firebaseService.getPlayer(uid);
    if (player != null && player.isInTeam && player.teamId != null) {
      // Logic to subscribe to FCM topics or listen to local feed
      firebaseService.getTeamActivityFeed(player.teamId!).listen((feed) {
        if (feed.isNotEmpty) {
          final latest = feed.first;
          // Only show if it happened in the last minute to avoid spamming old events on init
          if (latest.timestamp != null && 
              DateTime.now().difference(latest.timestamp!).inMinutes < 1) {
            _showTacticalNotification(latest);
          }
        }
      });
    }
  }

  void _showTacticalNotification(ActivityFeedModel event) {
    String title = "TACTICAL UPDATE";
    String body = "";

    switch (event.type) {
      case ActivityType.challengeStarted:
        title = "NEW MISSION ASSIGNED";
        body = "Operation ${event.itemId} is now active!";
        break;
      case ActivityType.challengeCompleted:
        title = "MISSION ACCOMPLISHED";
        body = "${event.itemId} target reached. Claim rewards now!";
        break;
      case ActivityType.rewardClaimed:
        title = "REWARD SECURED";
        body = "A squad member has claimed rewards for ${event.itemId}.";
        break;
      default:
        break;
    }

    if (body.isNotEmpty && mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _kSurfaceColor,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(body, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _ensureDailyChallenge(String uid) async {
    final player = await firebaseService.getPlayer(uid);
    if (player != null && player.isInTeam && player.teamId != null) {
      await firebaseService.rotateDailyChallenge(player.teamId!);
    }
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
                        final isJoined = team.id == currentPlayer.teamId;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: TeamCard(
                            team: team,
                            joined: isJoined,
                            onJoin: isJoined ? null : () => _handleJoinTeam(team, currentPlayer),
                            onTap: isJoined
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TeamMembersScreen(
                                          teamName: team.name,
                                          teamId: team.id,
                                          leaderId: team.leaderId,
                                        ),
                                      ),
                                    )
                                : null,
                          ),
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
          StreamBuilder<TeamChallengeModel?>(
            stream: firebaseService.getActiveTeamChallenge(team.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return _buildDailyChallenge(snapshot.data!);
            },
          ),
          const SizedBox(height: 32),
          _buildTeamQuickActions(team, player),
        ],
      ),
    );
  }

  Widget _buildTeamBanner(TeamModel team) {
    return GestureDetector(
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
      child: Container(
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
                  Text("CAPTAIN ID: ${team.leaderId.substring(0, (team.leaderId.length > 8 ? 8 : team.leaderId.length)).toUpperCase()}", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamStatsGrid(TeamModel team, PlayerModel player) {
    return GridView(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
          _miniStatCard("WEEKLY STEPS", team.totalSteps.toString(), Icons.directions_walk_rounded),
          _miniStatCard("TERRITORY", "12.4 KM²", Icons.map_rounded),
          _miniStatCard("CONTRIBUTION", "${player.dailySteps} TODAY", Icons.add_chart_rounded),
          _miniStatCard("TEAM BANK", team.teamCurrency.toString(), Icons.stars_rounded),
          StreamBuilder<List<TeamModel>>(
            stream: firebaseService.getTeamLeaderboardGlobal(),
            builder: (context, snapshot) {
              int rank = 0;
              if (snapshot.hasData) {
                final globalTeams = snapshot.data!;
                rank = globalTeams.indexWhere((t) => t.id == team.id) + 1;
              }
              return _miniStatCard("RANKING", rank > 0 ? "#$rank GLOBAL" : "UNRANKED", Icons.leaderboard_rounded);
            },
          ),
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

  Widget _buildDailyChallenge(TeamChallengeModel challenge) {
    final remaining = challenge.expiresAt.difference(DateTime.now());
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isClaimed = challenge.claimedMembers.contains(currentUid);
    final bool isCompleted = challenge.isCompleted;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCompleted 
            ? Colors.greenAccent.withValues(alpha: 0.2) 
            : Colors.orangeAccent.withValues(alpha: 0.1)
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isCompleted ? "MISSION COMPLETED" : "DAILY MISSION", 
                style: TextStyle(
                  color: isCompleted ? Colors.greenAccent : Colors.orangeAccent, 
                  fontSize: 10, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 1
                )
              ),
              if (!isCompleted)
                Text("${hours}H ${minutes}M REMAINING", style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(challenge.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(challenge.description, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (!isClaimed) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: challenge.percentage,
                minHeight: 6,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(isCompleted ? Colors.greenAccent : Colors.orangeAccent),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isClaimed)
                Text(
                  "${challenge.progress.toInt()} / ${challenge.target.toInt()} ${challenge.type == ChallengeType.steps ? 'STEPS' : 'UNIT'}",
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                )
              else
                const Text("REWARD SECURED", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              
              if (isCompleted && !isClaimed)
                ElevatedButton(
                  onPressed: () => _handleClaimReward(challenge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    minimumSize: const Size(0, 28),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("CLAIM", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                )
              else if (!isClaimed)
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.purpleAccent, size: 12),
                    Text(" +${challenge.xpReward}", style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Icon(Icons.monetization_on, color: Colors.amberAccent, size: 12),
                    Text(" +${challenge.currencyReward}", style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleClaimReward(TeamChallengeModel challenge) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final player = await firebaseService.getPlayer(uid!);
    if (player != null && player.teamId != null) {
      try {
        await firebaseService.claimTeamChallengeReward(player.teamId!, challenge.id, uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF161B22),
              content: Text("REWARDS SYNCHRONIZED TO PROFILE", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("CLAIM FAILED: $e")),
          );
        }
      }
    }
  }

  Widget _buildTeamQuickActions(TeamModel team, PlayerModel player) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isLeader = team.leaderId == currentUid;

    return Column(
      children: [
        if (isLeader) ...[
          StreamBuilder<List<TeamRequestModel>>(
            stream: firebaseService.getTeamRequests(team.id),
            builder: (context, snapshot) {
              final requestCount = snapshot.data?.length ?? 0;
              return _quickActionTile(
                "PENDING REQUESTS",
                Icons.person_add_alt_1_rounded,
                requestCount > 0 ? "$requestCount RECRUITS WAITING" : "NO PENDING RECRUITS",
                color: requestCount > 0 ? Colors.orangeAccent : _kPrimaryPurple,
                onTap: () => _showRequestsDialog(team),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        _quickActionTile(
          "TEAM ARMORY",
          Icons.shopping_cart_outlined,
          "EXCHANGE CURRENCY FOR BUFFS",
          color: Colors.blueAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TeamShopScreen(teamId: team.id),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _quickActionTile(
          "TEAM ACHIEVEMENTS",
          Icons.emoji_events_outlined,
          "UNLOCKED SQUAD MILESTONES",
          color: Colors.amberAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TeamAchievementsScreen(team: team),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _quickActionTile(
          "TEAM CHAT",
          Icons.chat_bubble_outline_rounded,
          "SECURE COMMS CHANNEL",
          onTap: () {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeamChatScreen(
                    teamId: team.id,
                    teamName: team.name,
                    playerName: player.name,
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        _quickActionTile("LEAVE TEAM", Icons.logout_rounded, "EXIT CURRENT SQUADRON", color: Colors.redAccent, onTap: () => _handleLeaveTeam(team)),
      ],
    );
  }

  Widget _quickActionTile(String title, IconData icon, String subtitle, {Color color = _kPrimaryPurple, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  void _showRequestsDialog(TeamModel team) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kSurfaceColor,
        title: const Text("PENDING RECRUITS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<List<TeamRequestModel>>(
            stream: firebaseService.getTeamRequests(team.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final requests = snapshot.data ?? [];
              if (requests.isEmpty) return const Center(child: Text("NO PENDING REQUESTS", style: TextStyle(color: Colors.white24)));

              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  return ListTile(
                    title: Text(req.playerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                          onPressed: () async {
                            try {
                              await firebaseService.acceptRequest(
                                requestId: req.requestId,
                                playerId: req.playerId,
                                teamId: team.id,
                                teamName: team.name,
                              );
                              if (context.mounted && requests.length == 1) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                String errorMsg = "RECRUITMENT FAILED";
                                if (e.toString().contains("TEAM_FULL")) {
                                  errorMsg = "SQUAD AT MAXIMUM CAPACITY";
                                } else if (e.toString().contains("PLAYER_ALREADY_IN_TEAM")) {
                                  errorMsg = "OPERATOR ALREADY ASSIGNED TO ANOTHER SQUAD";
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF161B22),
                                    content: Text(errorMsg, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.redAccent),
                          onPressed: () => firebaseService.rejectRequest(req.requestId),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE", style: TextStyle(color: Colors.white38))),
        ],
      ),
    );
  }

  Future<void> _handleLeaveTeam(TeamModel team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kSurfaceColor,
        title: const Text("LEAVE TEAM?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to exit this squadron?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("LEAVE", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await firebaseService.kickPlayer(playerId: uid, teamId: team.id);
      }
    }
  }

  void _showCreateTeamDialog(PlayerModel player) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kSurfaceColor,
        title: const Text("CREATE NEW TEAM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "TEAM NAME",
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kPrimaryPurple)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await firebaseService.createTeam(
                    name: nameController.text.trim(),
                    leaderId: player.uid,
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    String message = "SYSTEM ERROR";
                    if (e.toString().contains("TEAM_NAME_TAKEN")) {
                      message = "NAME ALREADY REGISTERED";
                    } else if (e.toString().contains("PLAYER_ALREADY_IN_TEAM")) {
                      message = "YOU ARE ALREADY IN A SQUAD";
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF161B22),
                        content: Text(message, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text("CREATE", style: TextStyle(color: _kPrimaryPurple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showJoinCodeDialog(PlayerModel player) {
    final TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kSurfaceColor,
        title: const Text("JOIN BY TEAM ID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        content: TextField(
          controller: codeController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "PASTE TEAM ID HERE",
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kPrimaryPurple)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              if (codeController.text.trim().isNotEmpty) {
                final teamId = codeController.text.trim();
                final request = TeamRequestModel(
                  requestId: "${player.uid}_$teamId",
                  playerId: player.uid,
                  playerName: player.name,
                  teamId: teamId,
                  teamName: "Request via ID",
                  status: "pending",
                );

                try {
                  await firebaseService.sendJoinRequest(request);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF161B22),
                        content: Text("SQUADRON REQUEST TRANSMITTED", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    String message = "COMMUNICATION ERROR: $e";
                    if (e.toString().contains("PLAYER_ALREADY_IN_TEAM")) {
                      message = "ACCESS DENIED: ALREADY ASSIGNED TO A SQUAD";
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF161B22),
                        content: Text(message, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text("SEND REQUEST", style: TextStyle(color: _kPrimaryPurple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleJoinTeam(TeamModel team, PlayerModel player) async {
    if (team.members >= team.maxMembers) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Team is full!")));
      }
      return;
    }

    final request = TeamRequestModel(
      requestId: "${player.uid}_${team.id}",
      playerId: player.uid,
      playerName: player.name,
      teamId: team.id,
      teamName: team.name,
      status: "pending",
    );

    try {
      await firebaseService.sendJoinRequest(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF161B22),
            content: Text("Join request sent to ${team.name.toUpperCase()}!", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = "Error: $e";
        if (e.toString().contains("PLAYER_ALREADY_IN_TEAM")) {
          message = "YOU ARE ALREADY ASSIGNED TO A SQUAD";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF161B22),
            content: Text(message, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        );
      }
    }
  }
}
