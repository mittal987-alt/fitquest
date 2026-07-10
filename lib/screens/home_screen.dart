import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/pedometer_service.dart';
import '../services/step_sync_service.dart';
import '../services/firebase_service.dart';
import '../models/player_model.dart';
import '../models/power_up_model.dart';
import '../models/global_event_model.dart';
import 'leaderboard_screen.dart';
import 'shop_screen.dart';
import 'tactical_relay_screen.dart';
import 'crafting_screen.dart';
import '../models/tactical_relay_model.dart';
import '../features/tactical/widgets/activity_heatmap.dart';
import '../widgets/energy_boost_badge.dart';

import '../features/raid/raid_history_screen.dart';

import 'package:provider/provider.dart';
import '../controller/raid_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PedometerService pedometerService = PedometerService();
  final StepSyncService stepSyncService = StepSyncService();
  final FirebaseService firebaseService = FirebaseService();
  late ConfettiController _confettiController;
  late Stream<PlayerModel?> _playerStream;
  StreamSubscription<TacticalPulse>? _pulseSubscription;
  Timer? refreshTimer;

  // Live Feature State
  bool _isGhostStriderActive = true;
  final Map<String, int> _ghostBaselineMap = {
    "08": 800, "09": 1200, "10": 600, "12": 1500, "13": 400, "17": 2000, "18": 1500,
  };

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    final String currentUid = firebaseService.auth.currentUser?.uid ?? "";
    _playerStream = firebaseService.getPlayerStream(currentUid);

    if (currentUid.isNotEmpty) {
      firebaseService.checkAndResetDailyStats(currentUid);
      
      // Start tracking with player context for RPG modifiers
      firebaseService.getPlayer(currentUid).then((player) {
        if (player != null) {
          pedometerService.startTracking(
            playerContext: player,
            initialSteps: player.dailySteps,
          );
          _subscribeToTacticalPulse();
          
          if (player.teamId != null && mounted) {
            context.read<RaidController>().initTeamRaid(player.teamId!);
          }
          
          // Initialize toggle state from player profile
          setState(() {
            _isGhostStriderActive = player.isGhostStriderEnabled;
          });
        }
      });

      stepSyncService.startTracking();
    }
  }

  void _subscribeToTacticalPulse() {
    _pulseSubscription?.cancel();
    _pulseSubscription = pedometerService.tacticalPulseStream.listen((pulse) async {
      final String currentUid = firebaseService.auth.currentUser?.uid ?? "";
      final player = await firebaseService.getPlayer(currentUid);
      
      if (mounted) {
        final double finalDamage = pulse.raidDamage; // PedometerService already applied bioDamageMult

        // Detect Critical Hit (Large damage delta)
        // Threshold of 50 HP damage represents a high-intensity movement or buffed strike
        if (finalDamage >= 50.0) {
          _confettiController.play();
        }

        setState(() {
          // Visual feedback for material discovery
          if (pulse.discoveredMaterial != null) {
            _showLootNotification("FOUND: ${pulse.discoveredMaterial}");
          }
        });

        // Background Persistence
        if (player != null) {
          // Contributing damage to shared team raid if in a team
          if (player.teamId != null) {
            final raidController = context.read<RaidController>();
            // Update local RaidController state immediately for reactive UI
            // Note: pulse.raidDamage already includes strength and energy multipliers
            raidController.registerPlayerSteps(
              player.uid, 
              pulse.steps, 
              damageOverride: pulse.raidDamage,
              isAheadOfGhost: pulse.isAheadOfGhost,
            );
            
            // Sync to Firestore
            await firebaseService.contributeRaidDamage(player.teamId!, pulse.raidDamage);

            // Sync total raid damage contribution for rewards
            await firebaseService.firestore.collection("players").doc(player.uid).update({
              "totalRaidDamage": FieldValue.increment(pulse.raidDamage.toInt()),
              if (pulse.isAheadOfGhost) "ghostRaidDamage": FieldValue.increment(pulse.raidDamage.toInt()),
            });
          }

          // Update Daily Stats (Steps, Calories, Distance) via StepSyncService 
          // Note: Pulse-based updates here are for high-frequency gameplay impact.
          // StepSyncService handles the authoritative hardware delta sync.

          // Persist discovered materials to Firebase inventory
          if (pulse.discoveredMaterial != null) {
            await firebaseService.addInventoryItem(player.uid, pulse.discoveredMaterial!, 1);
          }
        }
      }
    });
  }

  void _showLootNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.cyan,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    refreshTimer?.cancel();
    _pulseSubscription?.cancel();
    stepSyncService.stopTracking();
    super.dispose();
  }

  String _getRelativeSyncTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    return DateFormat('HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "FITQUEST HQ",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 18, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: const [
          EnergyBoostBadge(),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<PlayerModel?>(
            stream: _playerStream,
            builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }

          final player = snapshot.data;
          
          // Sync local toggle with player state to prevent "auto-off" UI resets
          if (player != null && _isGhostStriderActive != player.isGhostStriderEnabled) {
             _isGhostStriderActive = player.isGhostStriderEnabled;
          }

          final int liveSteps = player?.dailySteps ?? 0;
          final int liveCalories = player?.dailyCalories ?? 0;
          final double liveDistance = player?.dailyDistance ?? 0.0;
          final int streak = player?.streakCount ?? 0;

          // POWER-UP CHECK
          bool hasExpBoost = player?.activePowerUps.containsKey("boost") ?? false;
          if (hasExpBoost) {
            DateTime? expiry = player?.activePowerUps["boost"];
            if (expiry != null && expiry.isBefore(DateTime.now())) {
              hasExpBoost = false;
            }
          }

          // FITNESS CALCULATIONS
          double dailyGoalTarget = player?.dailyStepTarget.toDouble() ?? 10000;
          double goalProgress = (liveSteps / dailyGoalTarget).clamp(0.0, 1.0);

          // Movement Health Score
          int healthScore = (goalProgress * 100).toInt();
          String fitnessStatus = pedometerService.getFitnessLevel(liveSteps);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PLAYER STATUS
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "STATUS: ACTIVE",
                              style: TextStyle(color: Colors.cyan.shade700, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  player?.name.toUpperCase() ?? "NEW PLAYER",
                                  style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                ),
                                if (hasExpBoost) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                                    ),
                                    child: const Text("XP 2X", style: TextStyle(color: Colors.purple, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              firebaseService.getRankTitle(player?.level ?? 1),
                              style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Text("🔥 ", style: TextStyle(fontSize: 16)),
                            Text(
                              "$streak DAYS",
                              style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. STATS GRID
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    _buildModernStatCard(title: "DAILY STEPS", value: "$liveSteps", icon: Icons.directions_walk_rounded, color: Colors.cyanAccent),
                    _buildModernStatCard(title: "CALORIES", value: "$liveCalories", icon: Icons.local_fire_department_rounded, color: Colors.orangeAccent),
                    _buildModernStatCard(title: "DISTANCE", value: "${liveDistance.toStringAsFixed(2)} KM", icon: Icons.alt_route_rounded, color: Colors.greenAccent),
                    _buildModernStatCard(title: "STAMINA", value: "${player?.currentStamina ?? 0}", icon: Icons.bolt_rounded, color: Colors.amberAccent),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. DAILY STEP GOAL PROGRESS
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("DAILY STEP GOAL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
                          Text("${(goalProgress * 100).toStringAsFixed(0)}%", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan.shade700, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: goalProgress,
                          minHeight: 8,
                          backgroundColor: Colors.black.withValues(alpha: 0.05),
                          color: Colors.cyan.shade400,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "$liveSteps / ${dailyGoalTarget.toStringAsFixed(0)} STEPS COMPLETED",
                        style: const TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // MOVEMENT STATUS / HEALTH SCORE
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ConfettiWidget(
                            confettiController: _confettiController,
                            blastDirectionality: BlastDirectionality.explosive,
                            colors: const [Colors.cyanAccent, Colors.orangeAccent, Colors.purpleAccent],
                          ),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(
                                  value: goalProgress,
                                  strokeWidth: 5,
                                  backgroundColor: Colors.black.withValues(alpha: 0.05),
                                  color: healthScore > 75 ? Colors.greenAccent : (healthScore > 40 ? Colors.orangeAccent : Colors.redAccent),
                                ),
                              ),
                              Text(
                                "$healthScore",
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("MOVEMENT STATUS", style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                const SizedBox(height: 4),
                                Text(
                                  fitnessStatus.toUpperCase(),
                                  style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildBioMetric("STATUS", "OPTIMAL", Icons.favorite_rounded, Colors.redAccent),
                          _buildBioMetric("SYNC", "100%", Icons.sync_rounded, Colors.cyan),
                          _buildBioMetric("TEAM SPIRIT", "${player?.trustScore ?? 100}%", Icons.shield_rounded, Colors.greenAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (stepSyncService.lastSyncTime != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sync_rounded, size: 13, color: Colors.black38),
                        const SizedBox(width: 6),
                        Text(
                          "DATA SYNCED: ${_getRelativeSyncTime(stepSyncService.lastSyncTime!).toUpperCase()}",
                          style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
                _buildGhostStriderCard(player, liveSteps),
                const SizedBox(height: 16),
                _buildColossusRaidDashboard(player),
                const SizedBox(height: 16),
                _buildTeamTacticalRelayCard(player),
                const SizedBox(height: 20),

                // 4. ACTIVE GLOBAL OPERATION CARD
                StreamBuilder<GlobalEventModel?>(
                  stream: firebaseService.getActiveGlobalEvent(),
                  builder: (context, eventSnapshot) {
                    if (!eventSnapshot.hasData || eventSnapshot.data == null) return const SizedBox.shrink();

                    final event = eventSnapshot.data!;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade900, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "ACTIVE GLOBAL EVENT",
                                style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "LIVE",
                                  style: TextStyle(color: Colors.blue.shade100, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            event.title.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.description,
                            style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${(event.progress * 100).toStringAsFixed(1)}% COMPLETE",
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                "${event.currentSteps} / ${event.targetSteps} STEPS",
                                style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: event.progress,
                              minHeight: 6,
                              backgroundColor: Colors.white10,
                              color: Colors.blueAccent.shade100,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                if (player != null && player.activePowerUps.entries.any((e) => e.value.isAfter(DateTime.now()))) ...[
                  const Text("ACTIVE POWER-UPS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: player.activePowerUps.entries.where((e) => e.value.isAfter(DateTime.now())).map((entry) {
                        final powerUp = shopItems.firstWhere(
                          (s) => s.id == entry.key,
                          orElse: () => PowerUp(
                            id: entry.key,
                            name: "Unknown Buff",
                            description: "",
                            cost: 0,
                            icon: Icons.auto_awesome,
                            color: Colors.grey,
                            duration: Duration.zero,
                          ),
                        );
                        final remaining = entry.value.difference(DateTime.now());
                        final minutes = remaining.inMinutes;
                        final seconds = remaining.inSeconds % 60;

                        return Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: powerUp.color.withValues(alpha: 0.15), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: powerUp.color.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(powerUp.icon, color: powerUp.color, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(powerUp.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${minutes}m ${seconds}s REMAINING",
                                      style: TextStyle(color: powerUp.color, fontWeight: FontWeight.bold, fontSize: 9),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                const Text("DAILY QUESTS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1)),
                const SizedBox(height: 12),
                if (player != null) ...[
                  _buildQuest(
                    player: player, 
                    id: "morning_walker", 
                    title: "Morning Walk", 
                    target: 2000, 
                    current: _calculateMorningSteps(player), 
                    reward: 100, 
                    icon: Icons.wb_sunny_rounded, 
                    color: Colors.orangeAccent,
                    isLocked: DateTime.now().hour < 5 || DateTime.now().hour > 11,
                    lockMessage: "AVAILABLE 05:00 - 11:00",
                  ),
                  const SizedBox(height: 10),
                  _buildQuest(
                    player: player, 
                    id: "xp_hunter", 
                    title: "Daily Activity Goal", 
                    target: 500, 
                    current: player.xp.toDouble(), 
                    reward: 500, 
                    icon: Icons.bolt_rounded, 
                    color: Colors.purpleAccent
                  ),
                ],
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CraftingScreen())),
                        icon: const Icon(Icons.build_circle_rounded, color: Colors.cyan),
                        label: const Text("CRAFTING", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen())),
                        icon: const Icon(Icons.shopping_bag_rounded, color: Colors.purpleAccent),
                        label: const Text("SHOP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                    icon: const Icon(Icons.leaderboard_rounded, color: Colors.orangeAccent),
                    label: const Text("GLOBAL LEADERBOARD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(height: 24),

                const Text("RECENT REWARDS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.01),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildRewardItem(icon: Icons.flash_on_rounded, title: "Quest Reward", subtitle: "You earned 100 XP", color: Colors.amber.shade700),
                      const Divider(height: 20, thickness: 1, color: Colors.black12),
                      _buildRewardItem(icon: Icons.shield_rounded, title: "Daily Bonus", subtitle: "You earned 20 XP for activity", color: Colors.teal),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text("LIFETIME STATS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLifetimeStat("TOTAL STEPS", "${player?.totalSteps ?? 0}"),
                      Container(width: 1, height: 30, color: Colors.black12),
                      _buildLifetimeStat("TEAM TRUST", "${player?.trustScore ?? 0}%"),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
      ],
    ),
  );
}

  Widget _buildModernStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildGhostStriderCard(PlayerModel? player, int liveSteps) {
    if (player == null) return const SizedBox.shrink();

    // Dynamically generate baseline from history, fallback to simulation if new player
    final Map<String, int> historicalBaseline = pedometerService.generateHistoricalBaseline(player.dailyHistory);
    final Map<String, int> baseline = (historicalBaseline.isNotEmpty) 
        ? historicalBaseline
        : _ghostBaselineMap;

    return StreamBuilder<int>(
      stream: pedometerService.stepStream,
      builder: (context, stepSnapshot) {
        final currentSteps = stepSnapshot.data ?? liveSteps;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isGhostStriderActive ? Colors.deepPurpleAccent.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
              width: 1.5,
            ),
            boxShadow: [
              if (_isGhostStriderActive)
                BoxShadow(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_run_rounded, color: _isGhostStriderActive ? Colors.deepPurpleAccent : Colors.grey),
                      const SizedBox(width: 8),
                      const Text(
                        "GHOST CHALLENGE",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isGhostStriderActive,
                    activeThumbColor: Colors.deepPurpleAccent,
                    onChanged: (val) {
                      setState(() {
                        _isGhostStriderActive = val;
                      });
                      firebaseService.updateGhostStriderToggle(player.uid, val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Compare your steps with your past performance.",
                style: TextStyle(color: Colors.black45, fontSize: 11),
              ),
                if (_isGhostStriderActive) ...[
                const SizedBox(height: 16),
                ActivityHeatmap(
                  hourlySteps: player.hourlySteps,
                  ghostBaseline: pedometerService.compileGhostBaseline(baseline),
                ),
                const SizedBox(height: 16),
                StreamBuilder<GhostStatus>(
                  stream: pedometerService.getGhostStatusStream(pedometerService.compileGhostBaseline(baseline)),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    
                    final status = snapshot.data!;
                    final double progress = (currentSteps / status.ghostTarget).clamp(0.0, 2.0);

                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "YOUR CURRENT STEPS: $currentSteps",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                            ),
                            Text(
                              "GHOST TARGET: ${status.ghostTarget}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.deepPurpleAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress > 1.0 ? 1.0 : progress,
                            minHeight: 8,
                            backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.1),
                            color: status.isAhead ? Colors.greenAccent : Colors.deepPurpleAccent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              status.isAhead 
                                  ? "🔥 ${status.stepsAhead} STEPS AHEAD" 
                                  : "⚠️ ${status.stepsAhead} STEPS BEHIND",
                              style: TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold, 
                                color: status.isAhead ? Colors.green.shade700 : Colors.deepPurple
                              ),
                            ),
                            Text(
                              "SPEED: ${status.velocityIndex.toStringAsFixed(2)}x",
                              style: const TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (status.isAhead) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt, color: Colors.green, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  "DAMAGE MULTIPLIER: ${status.velocityIndex.toStringAsFixed(1)}x ACTIVE",
                                  style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  }
                ),
              ]
            ],
          ),
        );
      }
    );
  }

  Widget _buildColossusRaidDashboard(PlayerModel? player) {
    return Consumer<RaidController>(
      builder: (context, raidController, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fitness_center_rounded, color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "COLOSSUS RAID",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                  if (raidController.isRaidActive)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.history_rounded, size: 18, color: Colors.black38),
                          onPressed: () {
                            if (player?.teamId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RaidHistoryScreen(teamId: player!.teamId!),
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.record_voice_over_rounded, size: 16, color: Colors.orangeAccent),
                          onPressed: () {
                            if (player != null) {
                              raidController.sendTacticalPing(
                                player.uid, 
                                player.name, 
                                "MOVING TO INTERCEPT! GAINING VELOCITY."
                              );
                            }
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text("ACTIVE", style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                raidController.isRaidActive 
                  ? "BOSS: ${raidController.bossName}"
                  : "Scanning for nearby Colossus threats...",
                style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              if (raidController.isRaidActive) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "HP: ${raidController.bossCurrentHp.toStringAsFixed(0)} / ${raidController.bossMaxHp.toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    Text(
                      "${(raidController.bossHpPercentage * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orangeAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: raidController.bossHpPercentage,
                    minHeight: 8,
                    backgroundColor: Colors.black.withValues(alpha: 0.05),
                    color: Colors.orangeAccent,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (player?.teamId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RaidHistoryScreen(teamId: player!.teamId!),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text("VIEW RAID ARCHIVES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Colors.black12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeamTacticalRelayCard(PlayerModel? player) {
    return StreamBuilder<TacticalRelayModel?>(
      stream: player?.teamId != null 
          ? StepSyncService().challengeController.getTeamRelay(player!.teamId!)
          : const Stream.empty(),
      builder: (context, snapshot) {
        final challenge = snapshot.data;
        final bool isActive = challenge?.isActive ?? false;
        final bool isMyTurn = challenge?.currentPlayerId == firebaseService.auth.currentUser?.uid;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isMyTurn ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05)
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TACTICAL STEP RELAY", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isMyTurn ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? (isMyTurn ? "YOUR TURN" : "IN PROGRESS") : "INACTIVE",
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          color: isMyTurn ? Colors.blueAccent : Colors.black38
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (isActive) ...[
                Text(
                  isMyTurn ? "REMAINING STEPS" : "CURRENT OPERATOR",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38)
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isMyTurn ? "${challenge!.remainingSteps} Steps" : challenge!.currentPlayerName.toUpperCase(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (player?.teamId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TacticalRelayScreen(
                                teamId: player!.teamId!,
                                teamName: player.team,
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMyTurn ? Colors.blueAccent : Colors.black.withValues(alpha: 0.05),
                        foregroundColor: isMyTurn ? Colors.white : Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("VIEW RELAY"),
                    ),
                  ],
                ),
              ] else ...[
                const Text("No active team relay. Coordinate with your team to begin.", 
                  style: TextStyle(fontSize: 12, color: Colors.black45)
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      if (player?.teamId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TacticalRelayScreen(
                              teamId: player!.teamId!,
                              teamName: player.team,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("JOIN A TEAM TO ACCESS THIS CHALLENGE")),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Colors.black12),
                    ),
                    child: const Text("OPEN RELAY COMM"),
                  ),
                ),
              ],
            ],
          ),
        );
      }
    );
  }
  double _calculateMorningSteps(PlayerModel player) {
    int total = 0;
    for (int h = 5; h <= 11; h++) {
      total += player.hourlySteps[h.toString().padLeft(2, '0')] ?? 0;
    }
    return total.toDouble();
  }

  Widget _buildQuest({
    required PlayerModel player,
    required String id,
    required String title,
    required double target,
    required double current,
    required int reward,
    required IconData icon,
    required Color color,
    bool isLocked = false,
    String? lockMessage,
  }) {
    final bool isCompleted = current >= target;
    final bool isClaimed = player.claimedQuests.contains(id);
    final double progress = (current / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClaimed || isLocked ? Colors.black.withValues(alpha: 0.03) : color.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isClaimed || isLocked ? Colors.grey.shade100 : color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isClaimed || isLocked ? Colors.grey : color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: isClaimed || isLocked ? Colors.black38 : Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (isLocked && !isClaimed) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.lock_outline_rounded, size: 12, color: Colors.black26),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (isLocked && !isClaimed)
                  Text(
                    lockMessage ?? "LOCKED",
                    style: const TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.black.withValues(alpha: 0.04),
                            color: isClaimed ? Colors.grey.shade300 : color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "${current.toInt()} / ${target.toInt()}",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isClaimed ? Colors.black38 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isClaimed)
            const Text(
              "CLAIMED",
              style: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold),
            )
          else if (isLocked)
            const SizedBox.shrink()
          else if (isCompleted)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () async {
                if (id == "morning_walker") {
                  final now = DateTime.now();
                  if (now.hour < 5 || now.hour > 11) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("ACCESS DENIED: MORNING ROUTINE ONLY AVAILABLE 0500-1100 HOURS."),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                }
                _confettiController.play();
                await firebaseService.claimQuestReward(player.uid, id, reward);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("REWARD CLAIMED: +$reward XP EARNED!"),
                      backgroundColor: color,
                    ),
                  );
                }
              },
              child: const Text("CLAIM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
            )
          else
            Text(
              "+$reward XP",
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
        ],
      ),
    );
  }

  Widget _buildRewardItem({required IconData icon, required String title, required String subtitle, required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black45)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLifetimeStat(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.black38, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildBioMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black87),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.black38, letterSpacing: 0.5),
        ),
      ],
    );
  }
}