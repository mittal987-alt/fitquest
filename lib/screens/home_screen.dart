import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/game_theme.dart';
import '../services/pedometer_service.dart';
import '../services/step_sync_service.dart';
import '../services/firebase_service.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../models/team_challenge_model.dart';
import 'map_screen.dart';
import 'armory_screen.dart';
import 'tactical_relay_screen.dart';
import 'crafting_screen.dart';
import 'activity_screen.dart';
import 'profile_screen.dart';
import 'goal_adjustment_screen.dart';
import 'leaderboard_screen.dart';
import '../models/tactical_relay_model.dart';
import '../features/tactical/widgets/activity_heatmap.dart';
import '../widgets/energy_boost_badge.dart';

import '../features/raid/raid_boss_screen.dart';

import '../services/ai_coach_service.dart';
import '../services/music_service.dart';
import '../services/anti_cheat_service.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../controller/raid_controller.dart';

import 'achievements_screen.dart';
import 'friends_screen.dart';
import '../models/activity_feed_model.dart';
import '../widgets/activity_feed_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final PedometerService _pedometerService = PedometerService();
  final PedometerService pedometerService = _pedometerService;
  final StepSyncService stepSyncService = StepSyncService();
  final FirebaseService firebaseService = FirebaseService();
  final AICoachService aiCoachService = AICoachService();
  final MusicService musicService = MusicService();
  late final MovementTrackingService movementTrackingService;
  late ConfettiController _confettiController;
  late Stream<PlayerModel?> _playerStream;
  StreamSubscription<TacticalPulse>? _pulseSubscription;
  StreamSubscription<DriftEvent>? _driftSubscription;

  // Live Feature State
  bool _isGhostStriderActive = true;
  final Map<String, int> _ghostBaselineMap = {
    "08": 800, "09": 1200, "10": 600, "12": 1500, "13": 400, "17": 2000, "18": 1500,
  };

  bool _scanningNearbyItems = false;
  double _itemScanProgress = 0.0;

  // ============================================================
  // DESIGN SYSTEM TOKENS
  // ============================================================
  static const double _kCardRadius = 24;
  static const double _kSectionGap = 24;

  BoxDecoration _cardDecoration(ThemeData theme, {Color? borderColor, double borderWidth = 1}) {
    return BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(_kCardRadius),
      border: Border.all(
        color: borderColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.05),
        width: borderWidth,
      ),
      boxShadow: [
        if (theme.brightness == Brightness.light)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
      ],
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    movementTrackingService = MovementTrackingService(_pedometerService);

    final String currentUid = firebaseService.auth.currentUser?.uid ?? "";
    _playerStream = firebaseService.getPlayerStream(currentUid);

    if (currentUid.isNotEmpty) {
      firebaseService.checkAndResetDailyStats(currentUid);
      firebaseService.getPlayer(currentUid).then((player) {
        if (player != null) {
          pedometerService.startTracking(playerContext: player, initialSteps: player.dailySteps);
          _subscribeToTacticalPulse();
          movementTrackingService.startTracking(player.uid);
          if (player.teamId != null && mounted) {
            context.read<RaidController>().initTeamRaid(player.teamId!);
          }
          setState(() => _isGhostStriderActive = player.isGhostStriderEnabled);
        }
      });
      stepSyncService.startTracking();
      _subscribeToDriftEvents();
    }
  }

  void _subscribeToDriftEvents() {
    _driftSubscription?.cancel();
    _driftSubscription = stepSyncService.driftEventStream.listen((event) {
      if (mounted) _showSyncConflictDialog(event);
    });
  }

  void _showSyncConflictDialog(DriftEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kCardRadius)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 12),
            Text("SYNC CONFLICT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Anomalous telemetry drift detected. A large jump in steps was blocked to ensure RPG integrity.",
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 20),
            _conflictStat("DETECTED DELTA", "+${event.delta} STEPS"),
            _conflictStat("MAX THRESHOLD", "${event.threshold} STEPS"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("ACKNOWLEDGE", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _conflictStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black45)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  void _subscribeToTacticalPulse() {
    _pulseSubscription?.cancel();
    _pulseSubscription = pedometerService.tacticalPulseStream.listen((pulse) async {
      final String currentUid = firebaseService.auth.currentUser?.uid ?? "";
      final player = await firebaseService.getPlayer(currentUid);
      if (mounted) {
        if (player != null) stepSyncService.updateConfig(player);
        if (pulse.raidDamage >= 50.0) {
          _confettiController.play();
          // Check for raid-related achievements if needed
        }

        setState(() {
          if (_scanningNearbyItems) {
            _itemScanProgress += pulse.scanProgress;
            if (_itemScanProgress >= 1.0) {
              _itemScanProgress = 0.0;
              _scanningNearbyItems = false;
              _showLootNotification("Item Found: Rare Supply Cache!");
            }
          }
          if (pulse.discoveredMaterial != null) _showLootNotification("FOUND: ${pulse.discoveredMaterial}");
        });

        if (player != null) {
          if (player.teamId != null) {
            context.read<RaidController>().registerPlayerSteps(player.uid, pulse.steps, damageOverride: pulse.raidDamage, isAheadOfGhost: pulse.isAheadOfGhost);
            await firebaseService.contributeRaidDamage(player.teamId!, pulse.raidDamage);
            await firebaseService.firestore.collection("players").doc(player.uid).update({"totalRaidDamage": FieldValue.increment(pulse.raidDamage.toInt())});
          }
          if (pulse.discoveredMaterial != null) await firebaseService.addInventoryItem(player.uid, pulse.discoveredMaterial!, 1);
        }
      }
    });
  }

  void _showLootNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.cyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseSubscription?.cancel();
    _driftSubscription?.cancel();
    movementTrackingService.disposeTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<PlayerModel?>(
        stream: _playerStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: colorScheme.primary));
          }
          final player = snapshot.data;
          if (player != null) {
            stepSyncService.updateConfig(player);
            pedometerService.updatePlayerContext(player);
          }

          final int liveSteps = player?.dailySteps ?? 0;
          final int liveCalories = player?.dailyCalories ?? 0;
          final double liveDistance = player?.dailyDistance ?? 0.0;
          final int liveMinutes = (liveSteps / 100).floor(); 
          final int streak = player?.streakCount ?? 0;
          final int xp = player?.xp ?? 0;
          final int level = player?.level ?? 1;
          final double xpProgress = (xp % 1000) / 1000;
          final int stepTarget = player?.dailyStepTarget ?? 10000;
          final double stepProgress = (liveSteps / stepTarget).clamp(0.0, 1.0);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                                  child: Text(
                                    player?.name ?? "STRIDER",
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 28, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => MyApp.of(context)?.toggleDarkMode(),
                                  icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: colorScheme.onSurface),
                                ),
                                const EnergyBoostBadge(),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration(theme),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("LEVEL $level", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 14)),
                                  Text("${xp % 1000} / 1000 XP", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: xpProgress,
                                  minHeight: 10,
                                  backgroundColor: colorScheme.onSurface.withValues(alpha: 0.05),
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Text("🔥 ", style: TextStyle(fontSize: 18)),
                                  Text("$streak DAY STREAK", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(theme, "Today's Progress"),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: _cardDecoration(theme),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _metricItem(theme, Icons.directions_walk_rounded, "$liveSteps", "Steps", Colors.cyan),
                                _metricItem(theme, Icons.straighten_rounded, liveDistance.toStringAsFixed(1), "km", Colors.greenAccent),
                                _metricItem(theme, Icons.local_fire_department_rounded, "$liveCalories", "kcal", Colors.orangeAccent),
                                _metricItem(theme, Icons.timer_rounded, "$liveMinutes", "mins", Colors.purpleAccent),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: _kSectionGap),

                      _sectionHeader(theme, "Territory"),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: _cardDecoration(theme),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            StreamBuilder<List<ActivityFeedModel>>(
                              stream: player == null 
                                  ? const Stream.empty() 
                                  : firebaseService.getPlayerActivityStream(player.uid, type: ActivityType.capture),
                              builder: (context, snapshot) {
                                final now = DateTime.now();
                                final todayCaptures = snapshot.data?.where((activity) {
                                  if (activity.timestamp == null) return false;
                                  return activity.timestamp!.year == now.year &&
                                         activity.timestamp!.month == now.month &&
                                         activity.timestamp!.day == now.day;
                                }).length ?? 0;
                                return _territoryItem(theme, (todayCaptures * 0.025).toStringAsFixed(2), "Today (km²)", Colors.cyan);
                              }
                            ),
                            _territoryItem(theme, ((player?.totalLand ?? 0) * 0.025).toStringAsFixed(2), "Total Area", Colors.blueAccent),
                            if (player != null && player.isInTeam && player.teamId != null)
                              StreamBuilder<List<TeamModel>>(
                                stream: firebaseService.getTeamLeaderboardGlobal(),
                                builder: (context, snapshot) {
                                  int rank = 0;
                                  if (snapshot.hasData) {
                                    final globalTeams = snapshot.data!;
                                    rank = globalTeams.indexWhere((t) => t.id == player.teamId) + 1;
                                  }
                                  return _territoryItem(theme, rank > 0 ? "#$rank" : "--", "Team Rank", Colors.orangeAccent);
                                },
                              )
                            else
                              StreamBuilder<int>(
                                stream: player == null 
                                    ? const Stream.empty() 
                                    : firebaseService.getPlayerRankStream(player.totalLand),
                                builder: (context, snapshot) {
                                  final rank = snapshot.data ?? 0;
                                  return _territoryItem(theme, rank > 0 ? "#$rank" : "--", "Solo Rank", Colors.orangeAccent);
                                }
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: _kSectionGap),

                      _sectionHeader(theme, "Goal"),
                      GestureDetector(
                        onTap: player == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => GoalAdjustmentScreen(player: player))),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: _cardDecoration(theme),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("$liveSteps / $stepTarget Steps", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16)),
                                  Text("${(stepProgress * 100).toInt()}%", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 18)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: stepProgress,
                                  minHeight: 12,
                                  backgroundColor: colorScheme.onSurface.withValues(alpha: 0.05),
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: _kSectionGap),

                      _sectionHeader(theme, "Ghost Strider"),
                      _buildGhostStriderCard(theme, player, liveSteps),
                      const SizedBox(height: _kSectionGap),

                      _sectionHeader(theme, "AI Coach Insight"),
                      _buildAICoachCard(theme, player),
                      const SizedBox(height: _kSectionGap),

                      _sectionHeader(theme, "Combat Operations"),
                      _buildColossusRaidDashboard(theme, player),
                      const SizedBox(height: 12),
                      _buildTeamTacticalRelayCard(theme, player),
                      const SizedBox(height: _kSectionGap),

                      _sectionHeader(theme, "Discovery"),
                      _buildNearbyItemsRadar(theme),
                      const SizedBox(height: _kSectionGap),

                      _sectionHeader(theme, "Global Activity Feed"),
                      StreamBuilder<List<ActivityFeedModel>>(
                        stream: firebaseService.getActivityFeedStream(limit: 5),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          return ActivityFeedWidget(activities: snapshot.data!);
                        },
                      ),
                      const SizedBox(height: _kSectionGap),

                      _sectionHeader(theme, "Today's Mission"),
                      if (player != null && player.isInTeam && player.teamId != null && player.activeTeamChallengeId != null) ...[
                         StreamBuilder<TeamChallengeModel?>(
                           stream: firebaseService.getActiveTeamChallengeStream(player.teamId!, player.activeTeamChallengeId!),
                           builder: (context, snapshot) {
                             if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                             final challenge = snapshot.data!;
                             return Column(
                               children: [
                                 _buildQuest(
                                   theme: theme,
                                   player: player,
                                   id: challenge.id,
                                   title: challenge.title,
                                   target: challenge.target,
                                   current: challenge.progress,
                                   reward: challenge.xpReward, // Mapping to xpReward if needed or showing both
                                   icon: challenge.type == ChallengeType.steps ? Icons.group_rounded : Icons.explore_rounded,
                                   color: Colors.orangeAccent,
                                 ),
                                 const SizedBox(height: 12),
                               ],
                             );
                           }
                         ),
                      ],
                      if (player != null) ...[
                        _buildQuest(
                          theme: theme,
                          player: player,
                          id: "morning_walker",
                          title: "Walk 5 km",
                          target: 5000,
                          current: liveDistance * 1000,
                          reward: 100,
                          icon: Icons.directions_run_rounded,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(height: 12),
                        _buildQuest(
                          theme: theme,
                          player: player,
                          id: "territory_scout",
                          title: "Capture 2 Areas",
                          target: 2,
                          current: (player.dailyHistory[DateTime.now().toString().split(' ')[0]]?['captures'] ?? 0).toDouble(),
                          reward: 250,
                          icon: Icons.explore_rounded,
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(height: 12),
                        _buildQuest(
                          theme: theme,
                          player: player,
                          id: "xp_hunter",
                          title: "Earn 500 XP",
                          target: 500,
                          current: (xp % 1000).toDouble(),
                          reward: 500,
                          icon: Icons.bolt_rounded,
                          color: Colors.purpleAccent,
                        ),
                      ],
                      const SizedBox(height: _kSectionGap),

                      _sectionHeader(theme, "Quick Actions"),
                      Row(
                        children: [
                          Expanded(child: _buildOpButton(theme, "START WALK", Icons.directions_walk_rounded, Colors.greenAccent, () => Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityScreen(player: player))))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildOpButton(theme, "ARMORY", Icons.shield_rounded, Colors.purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArmoryScreen())))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildOpButton(theme, "RANKINGS", Icons.leaderboard_rounded, Colors.amberAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildOpButton(theme, "NETWORK", Icons.hub_rounded, Colors.blueAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendsScreen())))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildOpButton(theme, "ACHIEVEMENTS", Icons.workspace_premium_rounded, Colors.purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildOpButton(theme, "CRAFTING", Icons.precision_manufacturing_rounded, Colors.orangeAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CraftingScreen())))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _sectionHeader(theme, "Music Controls"),
                      Row(
                        children: [
                          Expanded(child: _buildOpButton(theme, "SPOTIFY", Icons.music_note_rounded, Colors.green, () => musicService.openSpotify())),
                          const SizedBox(width: 12),
                          Expanded(child: _buildOpButton(theme, "YT MUSIC", Icons.play_circle_fill_rounded, Colors.redAccent, () => musicService.openYouTubeMusic())),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  Widget _metricItem(ThemeData theme, IconData icon, String value, String unit, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(unit, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _territoryItem(ThemeData theme, String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildOpButton(ThemeData theme, String label, IconData icon, Color color, VoidCallback onTap, {bool fullWidth = false}) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
      ),
    );
  }



  Widget _buildGhostStriderCard(ThemeData theme, PlayerModel? player, int liveSteps) {
    if (player == null) return const SizedBox.shrink();
    final Map<String, int> historicalBaseline = pedometerService.generateHistoricalBaseline(player.dailyHistory);
    final Map<String, int> baseline = (historicalBaseline.isNotEmpty) ? historicalBaseline : _ghostBaselineMap;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(
        theme,
        borderColor: _isGhostStriderActive ? colorScheme.primary.withValues(alpha: 0.2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_motion_rounded, color: _isGhostStriderActive ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(width: 12),
                  Text("GHOST STRIDER", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: 0.5)),
                ],
              ),
              Switch.adaptive(
                value: _isGhostStriderActive,
                activeTrackColor: colorScheme.primary,
                onChanged: (val) {
                  setState(() => _isGhostStriderActive = val);
                  firebaseService.updateGhostStriderToggle(player.uid, val);
                },
              ),
            ],
          ),
          if (_isGhostStriderActive) ...[
            const SizedBox(height: 20),
            ActivityHeatmap(hourlySteps: player.hourlySteps, ghostBaseline: pedometerService.compileGhostBaseline(baseline)),
            const SizedBox(height: 20),
            StreamBuilder<GhostStatus>(
              stream: pedometerService.getGhostStatusStream(pedometerService.compileGhostBaseline(baseline)),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final status = snapshot.data!;
                final double progress = (liveSteps / status.ghostTarget).clamp(0.0, 1.0);
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${status.isAhead ? 'AHEAD' : 'BEHIND'} BY ${status.stepsAhead} STEPS",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: status.isAhead ? Colors.greenAccent : Colors.redAccent)),
                        Text("TARGET: ${status.ghostTarget}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: colorScheme.onSurface.withValues(alpha: 0.05),
                        color: status.isAhead ? Colors.greenAccent : colorScheme.primary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text("Enable to compete against your historical performance baselines.", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildColossusRaidDashboard(ThemeData theme, PlayerModel? player) {
    final String? teamId = player?.teamId;
    final colorScheme = theme.colorScheme;

    return Consumer<RaidController>(
      builder: (context, raidController, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(theme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fitness_center_rounded, color: Colors.orangeAccent),
                  const SizedBox(width: 12),
                  Expanded(child: Text("COLOSSUS RAID", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: colorScheme.onSurface))),
                  if (raidController.isRaidActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Text("LIVE", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (raidController.isRaidActive) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(raidController.bossName.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colorScheme.onSurface)),
                    Text("${(raidController.bossHpPercentage * 100).toStringAsFixed(0)}% HP", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.orangeAccent)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: raidController.bossHpPercentage, minHeight: 10, backgroundColor: colorScheme.onSurface.withValues(alpha: 0.05), color: Colors.orangeAccent),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: teamId == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RaidBossScreen(teamId: teamId))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("ENGAGE TARGET", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
              ] else
                Text("Deep-space sensors scanning for Colossus signatures...", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeamTacticalRelayCard(ThemeData theme, PlayerModel? player) {
    final teamId = player?.teamId;
    final teamName = player?.team;
    final colorScheme = theme.colorScheme;

    return StreamBuilder<TacticalRelayModel?>(
      stream: teamId != null ? stepSyncService.challengeController.getTeamRelay(teamId) : const Stream.empty(),
      builder: (context, snapshot) {
        final challenge = snapshot.data;
        final bool isActive = challenge?.isActive ?? false;
        final bool isMyTurn = challenge?.currentPlayerId == firebaseService.auth.currentUser?.uid;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(theme, borderColor: isMyTurn ? colorScheme.primary.withValues(alpha: 0.2) : null),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("TACTICAL RELAY", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: colorScheme.onSurface)),
              const SizedBox(height: 16),
              if (isActive) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isMyTurn ? "YOUR OBJECTIVE" : "CURRENT OPERATOR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.onSurface.withValues(alpha: 0.4))),
                          Text(isMyTurn ? "${challenge!.remainingSteps} STEPS" : challenge!.currentPlayerName.toUpperCase(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: teamId == null || teamName == null
                          ? null
                          : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TacticalRelayScreen(teamId: teamId, teamName: teamName))),
                      style: ElevatedButton.styleFrom(backgroundColor: isMyTurn ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.05), foregroundColor: isMyTurn ? colorScheme.onPrimary : colorScheme.onSurface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text("COMM LINK"),
                    ),
                  ],
                ),
              ] else
                Text("No active team operations. Signal your team to initiate relay.", style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNearbyItemsRadar(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar_rounded, color: Colors.cyanAccent),
                  const SizedBox(width: 12),
                  Text("PROXIMITY RADAR", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: 0.5)),
                ],
              ),
              if (_scanningNearbyItems) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.cyanAccent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.1))),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.cyan, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("SUPPLY CACHE DETECTED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.cyanAccent)),
                      Text("EST. DISTANCE: 342M", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                    ],
                  ),
                ),
                TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())), child: const Text("VIEW MAP", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.cyan))),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildAICoachCard(ThemeData theme, PlayerModel? player) {
    if (player == null) return const SizedBox.shrink();
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(theme, borderColor: Colors.blueAccent.withValues(alpha: 0.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: Colors.blueAccent),
              const SizedBox(width: 12),
              Text("TACTICAL ADVISOR", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            aiCoachService.generateDailyMotivation(player),
            style: TextStyle(color: colorScheme.onSurface, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    aiCoachService.getFitnessInsight(player),
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuest({required ThemeData theme, required PlayerModel player, required String id, required String title, required double target, required double current, required int reward, required IconData icon, required Color color}) {
    final bool isCompleted = current >= target;
    final bool isClaimed = player.claimedQuests.contains(id);
    final double progress = (current / target).clamp(0.0, 1.0);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isClaimed ? colorScheme.onSurface.withValues(alpha: 0.02) : color.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: isClaimed ? colorScheme.onSurface.withValues(alpha: 0.05) : color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: isClaimed ? colorScheme.onSurface.withValues(alpha: 0.2) : color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: isClaimed ? colorScheme.onSurface.withValues(alpha: 0.2) : colorScheme.onSurface)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: colorScheme.onSurface.withValues(alpha: 0.04), color: isClaimed ? colorScheme.onSurface.withValues(alpha: 0.1) : color))),
                    const SizedBox(width: 12),
                    Text("${current.toInt()}/${target.toInt()}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: colorScheme.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isClaimed)
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24)
          else if (isCompleted)
            IconButton(
              icon: Icon(Icons.card_giftcard_rounded, color: color),
              onPressed: () async {
                _confettiController.play();
                await firebaseService.claimQuestReward(player.uid, id, reward);
              },
            )
          else
            Text("+$reward XP", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
