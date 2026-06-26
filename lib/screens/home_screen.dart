import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';
import '../services/pedometer_service.dart';
import '../services/step_sync_service.dart';
import 'leaderboard_screen.dart';
import 'map_screen.dart';
import 'shop_screen.dart';
import '../models/player_model.dart';
import '../models/power_up_model.dart';
import '../services/firebase_service.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';

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

    // UPDATE STREAK & RESET QUESTS ON LAUNCH
    final uid = firebaseService.auth.currentUser?.uid;
    if (uid != null) {
      firebaseService.checkAndResetDailyStats(uid);
    }

    // AUTO REFRESH UI
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

  // UI Helper to match your clean card designs
  Widget _buildModernStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = firebaseService.auth.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "FitQuest",
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<PlayerModel?>(
        stream: firebaseService.getPlayerStream(currentUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final player = snapshot.data;

          // Fallbacks if data stream has missing values initially
          final int liveSteps = player?.totalSteps ?? 0;
          final int liveLevel = player?.level ?? 1;
          final int liveXp = player?.xp ?? 0;
          final int streak = player?.streakCount ?? 0;

          // Compute values derived from actual database items
          double calculatedCalories = liveSteps * 0.04;
          double calculatedDistance = liveSteps * 0.00075;

          // Goal tracker limits
          double dailyGoalTarget = 10000;
          double goalProgress = (liveSteps / dailyGoalTarget).clamp(0.0, 1.0);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =====================
                // HEADER BANNER
                // =====================
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E90FF), Color(0xFF00BFFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ]
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome Back 👋",
                              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Ready To Conquer?",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900, // FIXED: Changed from black to w900
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Text("🔥 ", style: TextStyle(fontSize: 18)),
                            Text(
                              "$streak",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // =====================
                // SYNC STATUS FLAG
                // =====================
                if (stepSyncService.lastSyncTime != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          "Synced ${_getRelativeSyncTime(stepSyncService.lastSyncTime!)}",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // =====================
                // REAL-DATA STATS GRID
                // =====================
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.15,
                  children: [
                    _buildModernStatCard(
                      title: "Steps",
                      value: "$liveSteps",
                      icon: Icons.directions_walk_rounded,
                      color: Colors.blue,
                    ),
                    _buildModernStatCard(
                      title: "Calories",
                      value: calculatedCalories.toStringAsFixed(0),
                      icon: Icons.local_fire_department_rounded,
                      color: Colors.orange,
                    ),
                    _buildModernStatCard(
                      title: "Distance",
                      value: "${calculatedDistance.toStringAsFixed(2)} km",
                      icon: Icons.alt_route_rounded,
                      color: Colors.green,
                    ),
                    _buildModernStatCard(
                      title: "Level",
                      value: "$liveLevel",
                      icon: Icons.star_rounded,
                      color: Colors.purple,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // =====================
                // DAILY GOAL PANEL
                // =====================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Daily Goal",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "${(goalProgress * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          )
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: goalProgress,
                          minHeight: 12,
                          backgroundColor: Colors.grey.shade100,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "$liveSteps / ${dailyGoalTarget.toStringAsFixed(0)} steps taken",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // =====================
                // DAILY QUESTS
                // =====================
                const Text(
                  "Daily Quests",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 14),
                if (player != null) ...[
                  _buildQuest(
                    player: player,
                    id: "morning_walker",
                    title: "Morning Walker",
                    target: 2000,
                    current: liveSteps.toDouble(),
                    reward: 100,
                    icon: Icons.wb_sunny_rounded,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildQuest(
                    player: player,
                    id: "territory_scout",
                    title: "Territory Scout",
                    target: 3,
                    current: player.totalLand.toDouble(),
                    reward: 250,
                    icon: Icons.explore_rounded,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildQuest(
                    player: player,
                    id: "xp_hunter",
                    title: "XP Hunter",
                    target: 500,
                    current: liveXp.toDouble(),
                    reward: 500,
                    icon: Icons.bolt_rounded,
                    color: Colors.purple,
                  ),
                ],

                const SizedBox(height: 28),

                // =====================
                // QUICK ACTIONS
                // =====================
                const Text(
                  "Quick Actions",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text("Open Map", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C27B0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen())),
                        icon: const Icon(Icons.shopping_bag_rounded),
                        label: const Text("Shop", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                    icon: const Icon(Icons.leaderboard_rounded),
                    label: const Text("Leaderboard", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 28),

                // =====================
                // REWARDS PREVIEW
                // =====================
                const Text(
                  "Recent Rewards",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      rewardItem(
                        icon: Icons.flash_on_rounded,
                        title: "Action Rewards",
                        subtitle: "Earn 100 XP for attacking tiles",
                        color: Colors.amber,
                      ),
                      const Divider(height: 24, thickness: 0.8),
                      rewardItem(
                        icon: Icons.shield_rounded,
                        title: "Defensive Bonus",
                        subtitle: "Defend tiles for 20 XP each",
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // =====================
                // FITNESS PANEL
                // =====================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        shouldLoop: false,
                        colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
                      ),
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Fitness Level",
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w500), // FIXED: Resolved whiteAA
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pedometerService.getFitnessLevel(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900, // FIXED: Changed from black to w900
                              ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isClaimed)
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22)
                    else
                      Text(
                        "$reward XP",
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!isClaimed) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      color: color,
                    ),
                  ),
                ],
                if (isComplete && !isClaimed)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          await firebaseService.claimQuest(
                            uid: player.uid,
                            questId: id,
                            rewardXp: reward,
                          );
                          if (!mounted) return;
                          _confettiController.play();
                        },
                        child: const Text("CLAIM REWARD", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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

  Widget rewardItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}