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
  bool isResting = false;
  int currentLap = 1;
  final int totalLaps = 3;

  @override
  Widget build(BuildContext context) {
    if (widget.player != null) {
      return _buildContent(widget.player!);
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
        return _buildContent(snapshot.data!);
      },
    );
  }

  Widget _buildContent(PlayerModel player) {
    // Generate tier model based on user weight for biometric scaling
    final activityModel = ActivityModel.fromWeight(player.weightKg ?? 80.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "TACTICAL SESSION: ${activityModel.tier}",
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildStatusHeader(player, activityModel),
            const SizedBox(height: 32),
            _buildLapCounter(),
            const SizedBox(height: 32),
            _buildTimerSection(activityModel),
            const SizedBox(height: 48),
            _buildActionButtons(player, activityModel),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(PlayerModel player, ActivityModel model) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("players").doc(player.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final powerUps = data["activePowerUps"] as Map<String, dynamic>? ?? {};
        final expiry = powerUps["metabolic_recharge"] as Timestamp?;
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
                      isRecharging ? "METABOLIC RECHARGE ACTIVE" : "RECHARGE SYSTEM OFFLINE",
                      style: TextStyle(
                        color: isRecharging ? Colors.blueAccent : Colors.white38,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRecharging 
                          ? "${model.xpMultiplier}x Multiplier applied to all telemetry." 
                          : "Complete this session to trigger bonus XP.",
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
            isResting ? "REST PROTOCOL" : "ACTIVE ENGAGEMENT",
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
                  title: "REST PROTOCOL COMPLETE",
                  body: "Engage next lap immediately. Stay in Flow.",
                );
                setState(() {
                  isResting = false;
                  if (currentLap < totalLaps) currentLap++;
                });
              },
            )
          else
            Column(
              children: [
                const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 64),
                const SizedBox(height: 16),
                Text(
                  "${model.durationMinutes ~/ totalLaps} MIN PER LAP",
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
        if (!isResting && currentLap <= totalLaps)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => isResting = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                "INITIATE REST INTERVAL",
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
              "FINALIZE SESSION",
              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _completeSession(PlayerModel player, ActivityModel model) async {
    try {
      await _service.logWorkoutAndRecharge(
        player.uid,
        model.durationMinutes, 
        model.tier
      );

      // Schedule notification for buff expiry (60 mins)
      await _notifications.scheduleNotification(
        id: 101,
        title: "METABOLIC RECHARGE EXPIRED",
        body: "Your 1.5x XP multiplier has faded. Initiate new session to stabilize.",
        scheduledDate: DateTime.now().add(const Duration(minutes: 60)),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("RECHARGE SEQUENCE ACTIVATED. XP MULTIPLIER ONLINE."),
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
