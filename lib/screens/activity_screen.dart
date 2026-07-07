import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../models/player_model.dart';
import '../models/activity_model.dart';
import '../widgets/rest_timer.dart';

class ActivityScreen extends StatefulWidget {
  final PlayerModel? player;
  const ActivityScreen({super.key, this.player});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final FirebaseService _service = FirebaseService();
  final NotificationService _notifications = NotificationService();
  ActivityModel? _activityModel;
  bool isResting = false;
  int currentLap = 1;
  final int totalLaps = 3;

  @override
  void initState() {
    super.initState();
    if (widget.player != null) {
      _activityModel = ActivityModel.fromBmiAndGoal(widget.player?.bmi, widget.player?.fitnessGoal);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.player != null) {
      return _buildContent(widget.player!, _activityModel!);
    }

    // If player not provided, fetch it using StreamBuilder
    final uid = _service.auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text("NOT LOGGED IN")));
    }

    return StreamBuilder<PlayerModel?>(
      stream: _service.getPlayerStream(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1117),
            body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          );
        }
        final player = snapshot.data!;
        _activityModel ??= ActivityModel.fromBmiAndGoal(player.bmi, player.fitnessGoal);
        return _buildContent(player, _activityModel!);
      },
    );
  }

  Widget _buildContent(PlayerModel player, ActivityModel activityModel) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "SESSION: ${activityModel.tier}",
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildProgressIndicator(),
            const SizedBox(height: 32),
            _buildStatusHeader(player, activityModel),
            const SizedBox(height: 32),
            _buildTimerSection(activityModel),
            const SizedBox(height: 24),
            _buildInstructionList(activityModel),
            const SizedBox(height: 48),
            _buildActionButtons(player, activityModel),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    double progress = currentLap / totalLaps;
    return Column(
      children: [
        Text("LAP $currentLap / $totalLaps", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress, color: Colors.blueAccent, backgroundColor: Colors.white10),
      ],
    );
  }

  Widget _buildInstructionList(ActivityModel model) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: model.exerciseGuide.length,
      itemBuilder: (context, index) {
        final ex = model.exerciseGuide[index];
        return Card(
          color: Colors.white.withValues(alpha: 0.05),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: const Icon(Icons.check_circle_outline, color: Colors.blueAccent),
            title: Text(
              ex['name']!, 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
            subtitle: Text(
              ex['tip']!, 
              style: const TextStyle(color: Colors.white54, fontSize: 12)
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(PlayerModel player, ActivityModel model) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("players").doc(player.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final powerUps = data["activePowerUps"] as Map<String, dynamic>? ?? {};
        final expiry = powerUps["energy_boost"] as Timestamp?;
        final bool isRecharging = expiry != null && expiry.toDate().isAfter(DateTime.now());

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isRecharging ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isRecharging ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                color: isRecharging ? Colors.blueAccent : Colors.white24,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRecharging ? "ENERGY BOOST ACTIVE" : "BOOST INACTIVE",
                      style: TextStyle(
                        color: isRecharging ? Colors.blueAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRecharging 
                          ? "BOOST ACTIVE: ${model.xpMultiplier}x XP Multiplier + ${model.raidDamageMultiplier}x Raid Bonus." 
                          : "Complete session to activate the ${model.tier} Energy Boost bonus.",
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLapCounter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalLaps, (index) {
        final bool isDone = index < currentLap - 1;
        final bool isCurrent = index == currentLap - 1;
        return Container(
          width: 60,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isDone 
                ? Colors.greenAccent 
                : (isCurrent ? Colors.blueAccent : Colors.white10),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildTimerSection(ActivityModel model) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(
            isResting ? "REST BREAK" : "ACTIVE EXERCISE",
            style: TextStyle(
              color: isResting ? Colors.amberAccent : Colors.greenAccent,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          if (isResting)
            RestTimer(
              initialSeconds: model.restIntervalSeconds,
              onTimerFinished: () {
                _notifications.showLocalNotification(
                  title: "REST BREAK COMPLETE",
                  body: "Start next set immediately. Stay focused.",
                );
                setState(() {
                  isResting = false;
                });
              },
            )
          else
            Column(
              children: [
                const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 64),
                const SizedBox(height: 16),
                Text(
                  "${model.durationMinutes ~/ totalLaps} MIN PER SET",
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                ),
                Text(
                  "TIER: ${model.tier}",
                  style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(PlayerModel player, ActivityModel model) {
    return Column(
      children: [
        if (!isResting && currentLap < totalLaps)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() {
                isResting = true;
                currentLap++;
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                "NEXT SET",
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => _completeSession(player, model),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.greenAccent, width: 2),
              ),
            ),
            child: const Text(
              "COMPLETE SESSION",
              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _completeSession(PlayerModel player, ActivityModel model) async {
    try {
      // Clear previous expiry notification if re-upping the buff
      await _notifications.cancelNotification(101);

      await _service.logWorkoutAndEnergyBoost(
        uid: player.uid,
        durationMinutes: model.durationMinutes, 
        tier: model.tier,
        xpMultiplier: model.xpMultiplier,
        raidMultiplier: model.raidDamageMultiplier,
        exercises: const ["Fitness Training"],
      );

      // Schedule notification for boost expiry (60 mins)
      await _notifications.scheduleNotification(
        id: 101,
        title: "ENERGY BOOST EXPIRED",
        body: "Your ${model.tier} multiplier (${model.xpMultiplier}x XP / ${model.raidDamageMultiplier}x Damage) has faded. Start a new session to reactivate.",
        scheduledDate: DateTime.now().add(const Duration(minutes: 60)),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ENERGY BOOST ACTIVATED. XP GAINS INCREASED."),
            backgroundColor: Colors.blueAccent,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}
