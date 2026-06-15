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

class HomeScreen extends StatefulWidget {

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {

  final PedometerService
  pedometerService =
  PedometerService();

  final StepSyncService
  stepSyncService =
  StepSyncService();

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

    // START PEDOMETER
    pedometerService
        .startListening();

    // START FIREBASE STEP SYNC
    stepSyncService
        .startTracking();

    // AUTO REFRESH UI
    refreshTimer = Timer.periodic(

      const Duration(
          seconds: 2),

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

    stepSyncService
        .stopTracking();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      Colors.grey.shade100,

      appBar: AppBar(

        title:
        const Text("FitQuest"),

        centerTitle: true,
      ),

      body:
      SingleChildScrollView(

        padding:
        const EdgeInsets.all(
            16),

        child: Column(

          crossAxisAlignment:
          CrossAxisAlignment
              .start,

          children: [

            // =====================
            // HEADER
            // =====================

            StreamBuilder<PlayerModel?>(
              stream: firebaseService.getPlayerStream(firebaseService.auth.currentUser!.uid),
              builder: (context, snapshot) {
                final player = snapshot.data;
                final streak = player?.streakCount ?? 0;

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.lightBlue],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Welcome Back 👋",
                            style: TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Ready To Conquer?",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (streak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "🔥 $streak",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }
            ),

            const SizedBox(
                height: 24),

            // =====================
            // STATS GRID
            // =====================

            GridView.count(

              shrinkWrap: true,

              physics:
              const NeverScrollableScrollPhysics(),

              crossAxisCount: 2,

              crossAxisSpacing:
              12,

              mainAxisSpacing:
              12,

              childAspectRatio:
              1.1,

              children: [

                StatCard(

                  title: "Steps",

                  value:
                  pedometerService
                      .totalSteps
                      .toString(),

                  icon: Icons
                      .directions_walk,

                  color:
                  Colors.blue,
                ),

                StatCard(

                  title:
                  "Calories",

                  value:
                  pedometerService
                      .calculateCalories()
                      .toStringAsFixed(
                      0),

                  icon: Icons
                      .local_fire_department,

                  color: Colors
                      .orange,
                ),

                StatCard(

                  title:
                  "Distance",

                  value:
                  "${pedometerService.calculateDistanceKm().toStringAsFixed(2)} km",

                  icon:
                  Icons.route,

                  color:
                  Colors.green,
                ),

                StatCard(

                  title:
                  "Level",

                  value:
                  pedometerService
                      .getLevel()
                      .toString(),

                  icon:
                  Icons.star,

                  color:
                  Colors.purple,
                ),
              ],
            ),

            const SizedBox(
                height: 28),

            // =====================
            // DAILY GOAL
            // =====================

            Container(

              padding:
              const EdgeInsets
                  .all(20),

              decoration:
              BoxDecoration(

                color:
                Colors.white,

                borderRadius:
                BorderRadius.circular(
                    24),

                boxShadow: [

                  BoxShadow(

                    color: Colors
                        .black12,

                    blurRadius:
                    10,

                    offset:
                    const Offset(
                        0,
                        4),
                  ),
                ],
              ),

              child: Column(

                crossAxisAlignment:
                CrossAxisAlignment
                    .start,

                children: [

                  const Text(

                    "Daily Goal",

                    style:
                    TextStyle(

                      fontSize:
                      22,

                      fontWeight:
                      FontWeight
                          .bold,
                    ),
                  ),

                  const SizedBox(
                      height: 16),

                  ClipRRect(

                    borderRadius:
                    BorderRadius.circular(
                        20),

                    child:
                    LinearProgressIndicator(

                      value:
                      pedometerService
                          .getGoalProgress(),

                      minHeight:
                      18,

                      backgroundColor:
                      Colors
                          .grey
                          .shade300,

                      color:
                      Colors.blue,
                    ),
                  ),

                  const SizedBox(
                      height: 12),

                  Text(

                    "${(pedometerService.getGoalProgress() * 100).toStringAsFixed(0)}% Completed",
                  ),
                ],
              ),
            ),

            // =====================
            // DAILY QUESTS
            // =====================
            const Text(
              "Daily Quests",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<PlayerModel?>(
              stream: firebaseService.getPlayerStream(firebaseService.auth.currentUser!.uid),
              builder: (context, snapshot) {
                final player = snapshot.data;
                if (player == null) return const SizedBox();

                return Column(
                  children: [
                    _buildQuest(
                      player: player,
                      id: "morning_walker",
                      title: "Morning Walker",
                      target: 2000,
                      current: player.totalSteps.toDouble(),
                      reward: 100,
                      icon: Icons.wb_sunny,
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
                      icon: Icons.explore,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildQuest(
                      player: player,
                      id: "xp_hunter",
                      title: "XP Hunter",
                      target: 500,
                      current: player.xp.toDouble(),
                      reward: 500,
                      icon: Icons.bolt,
                      color: Colors.purple,
                    ),
                  ],
                );
              }
            ),

            const SizedBox(height: 30),

            // =====================
            // QUICK ACTIONS
            // =====================

            const Text(

              "Quick Actions",

              style: TextStyle(

                fontSize: 24,

                fontWeight:
                FontWeight
                    .bold,
              ),
            ),

            const SizedBox(
                height: 16),

            Row(

              children: [

                Expanded(

                  child:
                  ElevatedButton.icon(

                    style:
                    ElevatedButton.styleFrom(

                      backgroundColor:
                      Colors.blue,

                      padding:
                      const EdgeInsets.symmetric(
                        vertical:
                        18,
                      ),

                      shape:
                      RoundedRectangleBorder(

                        borderRadius:
                        BorderRadius.circular(
                            18),
                      ),
                    ),

                    onPressed:
                        () {

                      Navigator
                          .push(

                        context,

                        MaterialPageRoute(

                          builder:
                              (_) =>
                          const MapScreen(),
                        ),
                      );
                    },

                    icon:
                    const Icon(
                        Icons.map),

                    label:
                    const Text(
                        "Open Map"),
                  ),
                ),

                const SizedBox(
                    width: 12),

                Expanded(
                  child:
                  ElevatedButton.icon(

                    style:
                    ElevatedButton.styleFrom(

                      backgroundColor:
                      Colors.purple,

                      padding:
                      const EdgeInsets.symmetric(
                        vertical:
                        18,
                      ),

                      shape:
                      RoundedRectangleBorder(

                        borderRadius:
                        BorderRadius.circular(
                            18),
                      ),
                    ),

                    onPressed:
                        () {

                      Navigator
                          .push(

                        context,

                        MaterialPageRoute(

                          builder:
                              (_) =>
                          const ShopScreen(),
                        ),
                      );
                    },

                    icon:
                    const Icon(
                        Icons.shopping_bag),

                    label:
                    const Text(
                        "Shop"),
                  ),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
                    },
                    icon: const Icon(Icons.leaderboard),
                    label: const Text("Leaderboard"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // =====================
            // REWARDS PREVIEW
            // =====================
            const Text(
              "Recent Rewards",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  rewardItem(
                    icon: Icons.flash_on,
                    title: "Action Rewards",
                    subtitle: "Earn 100 XP for attacking tiles",
                    color: Colors.amber,
                  ),
                  const Divider(height: 24),
                  rewardItem(
                    icon: Icons.shield,
                    title: "Defensive Bonus",
                    subtitle: "Defend tiles for 20 XP each",
                    color: Colors.blue,
                  ),
                ],
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
                    },
                    icon: const Icon(Icons.leaderboard),
                    label: const Text("Leaderboard"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // =====================
            // FITNESS STATUS
            // =====================

            Container(

              padding:
              const EdgeInsets
                  .all(20),

              decoration:
              BoxDecoration(

                gradient:
                const LinearGradient(

                  colors: [

                    Colors.green,

                    Colors.teal,
                  ],
                ),

                borderRadius:
                BorderRadius.circular(
                    24),
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

                    radius: 30,

                    backgroundColor:
                    Colors
                        .white24,

                    child: Icon(

                      Icons.favorite,

                      color:
                      Colors.white,

                      size: 32,
                    ),
                  ),

                  const SizedBox(
                      width: 16),

                  Expanded(

                    child: Column(

                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                      children: [

                        const Text(

                          "Fitness Level",

                          style:
                          TextStyle(

                            color: Colors
                                .white70,

                            fontSize:
                            16,
                          ),
                        ),

                        const SizedBox(
                            height:
                            6),

                        Text(

                          pedometerService
                              .getFitnessLevel(),

                          style:
                          const TextStyle(

                            color: Colors
                                .white,

                            fontSize:
                            28,

                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<PlayerModel?>(
                    stream: firebaseService.getPlayerStream(firebaseService.auth.currentUser!.uid),
                    builder: (context, snapshot) {
                      final player = snapshot.data;
                      if (player == null || player.activePowerUps.isEmpty) return const SizedBox();
                      
                      return Row(
                        children: player.activePowerUps.entries.map((entry) {
                          final isExpired = entry.value.isBefore(DateTime.now());
                          if (isExpired) return const SizedBox();

                          final powerUp = shopItems.firstWhere((p) => p.id == entry.key, orElse: () => shopItems[0]);

                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Tooltip(
                              message: "${powerUp.name} active",
                              child: Icon(powerUp.icon, color: Colors.white, size: 24),
                            ),
                          );
                        }).toList(),
                      );
                    }
                  ),
                ],
              ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (isClaimed)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20)
                    else
                      Text(
                        "$reward XP",
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!isClaimed)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      color: color,
                    ),
                  ),
                if (isComplete && !isClaimed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          await firebaseService.claimQuest(
                            uid: player.uid,
                            questId: id,
                            rewardXp: reward,
                          );
                          _confettiController.play();
                        },
                        child: const Text("CLAIM REWARD", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget questCard({
    required String title,
    required double progress,
    required String reward,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      reward,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
