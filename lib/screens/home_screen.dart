import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import '../services/pedometer_service.dart';
import '../services/step_sync_service.dart';
import '../services/firebase_service.dart';
import '../models/player_model.dart';
import '../models/power_up_model.dart';
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
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    final uid = firebaseService.auth.currentUser?.uid;
    if (uid != null) {
      firebaseService.checkAndResetDailyStats(uid);
    }

    refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
          (timer) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    refreshTimer?.cancel();
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
        stream: firebaseService.getPlayerStream(currentUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }

          final player = snapshot.data;
          final int liveSteps = player?.dailySteps ?? 0;
          final int liveLevel = player?.level ?? 1;
          final int liveXp = player?.xp ?? 0;
          final int streak = player?.streakCount ?? 0;

          double calculatedCalories = liveSteps * 0.04;
          double calculatedDistance = liveSteps * 0.00075;
          double dailyGoalTarget = 10000;
          double goalProgress = (liveSteps / dailyGoalTarget).clamp(0.0, 1.0);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // STATUS HEADER
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
                            Text(
                              player?.name.toUpperCase() ?? "EXPLORER NODE",
                              style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
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

                // SYNC TELEMETRY TIMESTAMP
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

                // CORE PERFORMANCE MATRIX GRID
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
                    _buildModernStatCard(title: "RANK LEVEL", value: "$liveLevel", icon: Icons.star_rounded, color: Colors.purpleAccent),
                  ],
                ),
                const SizedBox(height: 20),

                // SYSTEM PROGRESS BAR GOAL
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

                // ACTIVE AUGMENTATIONS LAYER
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

                // MATRICULATED QUEST SYSTEM LAYER
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

                // FAST WARPING SECTOR NAVIGATION
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

                // PERFORMANCE REWARD TELEMETRY LOGS
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
                      _buildRewardItem(icon: Icons.shield_rounded, title: "Node Defense Baseline", subtitle: "Secured 20 XP firewall perimeter rewards", color: Colors.cyan.shade700),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // LIFETIME OPERATIONAL DATA
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

                // DYNAMIC INTEGRATED CAPACITY MATRIX
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
                  child: Row(
                    children: [
                      ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        colors: const [Colors.cyanAccent, Colors.orangeAccent, Colors.purpleAccent],
                      ),
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFF5F7FA),
                        child: Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("BIO-INDEX ENGINE STATUS", style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              pedometerService.getFitnessLevel().toUpperCase(),
                              style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
    final bool isClaimed = player.claimedQuests.contains(id);
    final double progress = (current / target).clamp(0.0, 1.0);
    final bool isComplete = progress >= 1.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87, letterSpacing: 0.2), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    if (isClaimed)
                      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18)
                    else
                      Text("+$reward XP", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
                if (!isClaimed) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: Colors.black.withValues(alpha: 0.05), color: color),
                  ),
                ],
                if (isComplete && !isClaimed)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color.withValues(alpha: 0.2),
                          foregroundColor: color,
                          elevation: 0,
                          side: BorderSide(color: color.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await firebaseService.claimQuest(uid: player.uid, questId: id, rewardXp: reward);
                          if (!mounted) return;
                          _confettiController.play();
                        },
                        child: const Text("DECRYPT ACCRUED REWARD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifetimeStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildRewardItem({required IconData icon, required String title, required String subtitle, required Color color}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.black45, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}