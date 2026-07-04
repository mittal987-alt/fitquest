import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import '../services/pedometer_service.dart';
import '../services/step_sync_service.dart';
import '../services/firebase_service.dart';
import '../models/player_model.dart';
import '../models/power_up_model.dart';
import '../models/global_event_model.dart';
import 'leaderboard_screen.dart';
import 'map_screen.dart';
import 'shop_screen.dart';

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
  bool _isGhostStriderActive = false;
  final Map<String, int> _ghostBaselineMap = {
    "08": 800, "09": 1200, "10": 600, "12": 1500, "13": 400, "17": 2000, "18": 1500,
  };

  bool _anomalyScanning = false;
  double _anomalyScanProgress = 0.0;
  final double _anomalyDistance = 342.0; 

  double _colossusHp = 72400.0;
  final double _colossusMaxHp = 100000.0;
  bool _systemHackActive = true;

  bool _isMyRelayShiftActive = true;
  int _relayStepsRemaining = 3500;
  String _activeRelayPartner = "Operator_Alpha";

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
          pedometerService.startTracking(playerContext: player);
          _subscribeToTacticalPulse();
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
        setState(() {
          // Update Local Visual Raid HP (for immediate feedback)
          _colossusHp = (_colossusHp - pulse.raidDamage).clamp(0.0, _colossusMaxHp);
          
          // Update Anomaly Scanning
          if (_anomalyScanning) {
            _anomalyScanProgress += pulse.scanProgress;
            if (_anomalyScanProgress >= 1.0) {
              _anomalyScanProgress = 0.0;
              _anomalyScanning = false;
              _showLootNotification("Anomaly Decrypted: Found Rare Data Cache!");
            }
          }

          // Visual feedback for material discovery
          if (pulse.discoveredMaterial != null) {
            _showLootNotification("SCANNED: Found ${pulse.discoveredMaterial}");
          }
        });

        // Background Persistence
        if (player != null) {
          // Contribute damage to shared team raid if in a team
          if (player.teamId != null) {
            await firebaseService.contributeRaidDamage(player.teamId!, pulse.raidDamage);
          }

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
    final String currentUid = firebaseService.auth.currentUser?.uid ?? "";

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
      ),
      body: StreamBuilder<PlayerModel?>(
        stream: _playerStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }

          final player = snapshot.data;
          final int liveSteps = player?.dailySteps ?? 0;
          final int liveLevel = player?.level ?? 1;
          final int liveXp = player?.xp ?? 0;
          final int streak = player?.streakCount ?? 0;

          // AUGMENTATION CHECK
          bool hasExpBoost = player?.activePowerUps.containsKey("boost") ?? false;
          if (hasExpBoost) {
            DateTime? expiry = player?.activePowerUps["boost"];
            if (expiry != null && expiry.isBefore(DateTime.now())) {
              hasExpBoost = false;
            }
          }

          // BIO-INDEX CALCULATIONS
          double calculatedCalories = liveSteps * 0.04;
          double calculatedDistance = liveSteps * 0.00075;
          double dailyGoalTarget = player?.dailyStepTarget.toDouble() ?? 10000;
          double goalProgress = (liveSteps / dailyGoalTarget).clamp(0.0, 1.0);

          // Telemetry Health Score (Simplified BIO-INDEX)
          int healthScore = (goalProgress * 100).toInt();
          String bioStatus = pedometerService.getFitnessLevel(liveSteps);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ACTIVE GLOBAL OPERATION CARD
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
                                "ACTIVE GLOBAL OPERATION",
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

                // 2. OPERATOR STATUS
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
                              "OPERATOR STATUS: ACTIVE",
                              style: TextStyle(color: Colors.cyan.shade700, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  player?.name.toUpperCase() ?? "EXPLORER NODE",
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

                if (stepSyncService.lastSyncTime != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sync_rounded, size: 13, color: Colors.black38),
                        const SizedBox(width: 6),
                        Text(
                          "TELEMETRY UPDATED: ${_getRelativeSyncTime(stepSyncService.lastSyncTime!).toUpperCase()}",
                          style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),

                // 3. STATS GRID
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    _buildModernStatCard(title: "DAILY STRIDES", value: "$liveSteps", icon: Icons.directions_walk_rounded, color: Colors.cyanAccent),
                    _buildModernStatCard(title: "ENERGY KCAL", value: calculatedCalories.toStringAsFixed(0), icon: Icons.local_fire_department_rounded, color: Colors.orangeAccent),
                    _buildModernStatCard(title: "DISTANCE MAP", value: "${calculatedDistance.toStringAsFixed(2)} KM", icon: Icons.alt_route_rounded, color: Colors.greenAccent),
                    _buildModernStatCard(title: "STAMINA AP", value: "${player?.currentStamina ?? 0}", icon: Icons.bolt_rounded, color: Colors.amberAccent),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. SOLO FEATURE: "GHOST STRIDER" TELEMETRY TRIAL
                _buildGhostStriderCard(player, liveSteps),
                const SizedBox(height: 16),

                // 5. SOLO FEATURE: "GRID ANOMALIES" RADAR & CRAFTING INVENTORY
                _buildGridAnomalyRadar(),
                const SizedBox(height: 20),

                // 6. TEAM FEATURE: "COLOSSUS GRID-BREAKER" CO-OP RAID
                _buildColossusRaidDashboard(),
                const SizedBox(height: 20),

                // 7. TEAM FEATURE: "TELEMETRY RELAY" SEQUENCE CHALLENGE
                _buildTelemetryRelayCard(),
                const SizedBox(height: 20),

                // 8. DAILY SECTOR GOAL PROGRESS
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
                          const Text("DAILY SECTOR GOAL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
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
                        "$liveSteps / ${dailyGoalTarget.toStringAsFixed(0)} STRIDES COMPLETED",
                        style: const TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (player != null && player.activePowerUps.entries.any((e) => e.value.isAfter(DateTime.now()))) ...[
                  const Text("ACTIVE AUGMENTATIONS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: player.activePowerUps.entries.where((e) => e.value.isAfter(DateTime.now())).map((entry) {
                        final powerUp = shopItems.firstWhere((s) => s.id == entry.key);
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

                const Text("TACTICAL DAILY QUESTS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1)),
                const SizedBox(height: 12),
                if (player != null) ...[
                  _buildQuest(player: player, id: "morning_walker", title: "Morning Scout Routine", target: 2000, current: liveSteps.toDouble(), reward: 100, icon: Icons.wb_sunny_rounded, color: Colors.orangeAccent),
                  const SizedBox(height: 10),
                  _buildQuest(player: player, id: "territory_scout", title: "Grid Perimeter Expansion", target: 3, current: player.totalLand.toDouble(), reward: 250, icon: Icons.explore_rounded, color: Colors.cyanAccent),
                  const SizedBox(height: 10),
                  _buildQuest(player: player, id: "xp_hunter", title: "Core Processor Linkup", target: 500, current: liveXp.toDouble(), reward: 500, icon: Icons.bolt_rounded, color: Colors.purpleAccent),
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
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
                        icon: const Icon(Icons.map_rounded, color: Colors.cyan),
                        label: const Text("GRID MAP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
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
                        label: const Text("UPGRADES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
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
                    label: const Text("GLOBAL STANDINGS NODE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(height: 24),

                const Text("HISTORICAL CACHE LOGS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1)),
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
                      _buildRewardItem(icon: Icons.flash_on_rounded, title: "Grid Conquest Matrix", subtitle: "Dispatched 100 XP allocation via tile vectors", color: Colors.amber.shade700),
                      const Divider(height: 20, thickness: 1, color: Colors.black12),
                      _buildRewardItem(icon: Icons.shield_rounded, title: "Node Defense Baseline", subtitle: "Secured 20 XP firewall perimeter rewards", color: Colors.teal),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text("LIFETIME OPERATIONAL DATA", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1)),
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
                      _buildLifetimeStat("TOTAL STRIDES", "${player?.totalSteps ?? 0}"),
                      Container(width: 1, height: 30, color: Colors.black12),
                      _buildLifetimeStat("SECTORS HELD", "${player?.totalLand ?? 0}"),
                      Container(width: 1, height: 30, color: Colors.black12),
                      _buildLifetimeStat("CORE TRUST", "${player?.trustScore ?? 0}%"),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

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
                                const Text("BIO-INDEX CORE STATUS", style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                const SizedBox(height: 4),
                                Text(
                                  bioStatus.toUpperCase(),
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
                          _buildBioMetric("PULSE", "OPTIMAL", Icons.favorite_rounded, Colors.redAccent),
                          _buildBioMetric("SYNC", "100%", Icons.sync_rounded, Colors.cyan),
                          _buildBioMetric("INTEGRITY", "${player?.trustScore ?? 100}%", Icons.shield_rounded, Colors.greenAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
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

  // UI COMPONENT: GHOST STRIDER DATA STREAM VISUALS
  Widget _buildGhostStriderCard(PlayerModel? player, int liveSteps) {
    final Map<String, int> baseline = (player?.hourlyTelemetry != null && player!.hourlyTelemetry.isNotEmpty) 
        ? player.hourlyTelemetry 
        : _ghostBaselineMap;

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
                    "GHOST STRIDER TRIAL",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 0.5),
                  ),
                ],
              ),
              Switch(
                value: _isGhostStriderActive,
                activeColor: Colors.deepPurpleAccent,
                onChanged: (val) {
                  setState(() {
                    _isGhostStriderActive = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Synthesize steps against your historical telemetry curve.",
            style: TextStyle(color: Colors.black45, fontSize: 11),
          ),
          if (_isGhostStriderActive) ...[
            const SizedBox(height: 16),
            StreamBuilder<GhostStatus>(
              stream: pedometerService.getGhostStatusStream(pedometerService.compileGhostBaseline(baseline)),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                
                final status = snapshot.data!;
                final double progress = (liveSteps / status.ghostTarget).clamp(0.0, 2.0);

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "YOUR CURRENT STRIDES: $liveSteps",
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
                              ? "🔥 ${status.stepsAhead} STEPS AHEAD OF GHOST" 
                              : "⚠️ ${status.stepsAhead} STEPS BEHIND GHOST",
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: status.isAhead ? Colors.green.shade700 : Colors.deepPurple
                          ),
                        ),
                        Text(
                          "VELOCITY: ${status.velocityIndex.toStringAsFixed(2)}x",
                          style: const TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  ],
                );
              }
            ),
          ]
        ],
      ),
    );
  }

  // UI COMPONENT: GRID RADAR FOR ANOMALIES
  Widget _buildGridAnomalyRadar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar_rounded, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  const Text(
                    "GRID ANOMALIES RADAR",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 0.5),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.sync, size: 18, color: _anomalyScanning ? Colors.cyan : Colors.grey),
                onPressed: () {
                  setState(() {
                    _anomalyScanning = true;
                  });
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      setState(() {
                        _anomalyScanning = false;
                      });
                    }
                  });
                },
              )
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _anomalyScanning 
              ? "DECRYPTING ANOMALY: ${(_anomalyScanProgress * 100).toStringAsFixed(1)}%"
              : "Scanning physical coordinate vectors within radius r <= 500m.",
            style: TextStyle(
              color: _anomalyScanning ? Colors.cyan : Colors.black54, 
              fontSize: 11,
              fontWeight: _anomalyScanning ? FontWeight.bold : FontWeight.normal
            ),
          ),
          if (_anomalyScanning) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _anomalyScanProgress,
              minHeight: 4,
              backgroundColor: Colors.cyanAccent.withValues(alpha: 0.1),
              color: Colors.cyan,
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.cyan, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ACTIVE NODE DETECTED",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.cyan),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Coordinates located \${_anomalyDistance.toStringAsFixed(0)}m away on perimeter segment",
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
                  child: const Text("RADAR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CRAFTING BACKLOG:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38)),
              Text("Combine Elements in Upgrades Tab", style: TextStyle(fontSize: 9, color: Colors.black26)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRawElementChip("Raw Silicon", 4, Colors.amber),
              const SizedBox(width: 8),
              _buildRawElementChip("Dark Energy Core", 1, Colors.deepPurple),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRawElementChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text("\$x\$ ", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(
            "$count $label",
            style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // UI COMPONENT: CO-OP RAID HEALTH TRACKER
  Widget _buildColossusRaidDashboard() {
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
              const Icon(Icons.gavel_rounded, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "COLOSSUS GRID-BREAKER RAID",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Every step taken by the Operator Cell inflicts structural damage to defenses targeting a collectively aggregated pool of 100,000 HP.",
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          // FIXED: Interpolation and layout constraints
          Text(
            "GLITCH COLOSSUS INTEGRITY: ${_colossusHp.toStringAsFixed(0)} HP",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _colossusHp / _colossusMaxHp,
            backgroundColor: Colors.black.withValues(alpha: 0.05),
            color: Colors.orangeAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryRelayCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TELEMETRY RELAY SHIFT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 12),
          const Text("YOUR REMAINING TARGET", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38)),
          const SizedBox(height: 8),
          Row(
            children: [
              // FIXED: Expanded prevents Row overflow
              Expanded(
                child: Text(
                  "$_relayStepsRemaining Strides",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                child: const Text("PASS TOKEN"),
              ),
            ],
          ),
        ],
      ),
    );
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
          color: isClaimed ? Colors.black.withValues(alpha: 0.03) : color.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isClaimed ? Colors.grey.shade100 : color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isClaimed ? Colors.grey : color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: isClaimed ? Colors.black38 : Colors.black87,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
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
          else if (isCompleted)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () async {
                _confettiController.play();
                await firebaseService.claimQuestReward(player.uid, id, reward);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("REWARD SECURED: +$reward XP DEPLOYED!"),
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