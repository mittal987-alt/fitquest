import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:pedometer/pedometer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'pedometer_service.dart';
import '../models/player_model.dart';
import '../controller/tactical_relay_controller.dart';

class StepSyncService {
  static final StepSyncService _instance = StepSyncService._internal();
  factory StepSyncService() => _instance;
  StepSyncService._internal();

  final FirebaseService firebaseService = FirebaseService();
  final TacticalRelayController challengeController = TacticalRelayController();
  StreamSubscription<StepCount>? stepStream;
  DateTime? lastSyncTime;

  bool _isProcessing = false;
  PlayerModel? cachedPlayer;

  void updateConfig(PlayerModel? player) {
    cachedPlayer = player;
  }

  void startTracking() {
    if (stepStream != null) return;

    stepStream = Pedometer.stepCountStream.listen(
      (StepCount event) async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        if (_isProcessing) return;
        _isProcessing = true;

        try {
          // 1. Fetch latest player state from cloud to get lastHardwareStepCount
          final player = await firebaseService.getPlayer(uid);
          if (player == null) return;
          cachedPlayer = player;

          int currentHardwareSteps = event.steps;
          int lastHardwareSteps = player.lastHardwareStepCount;

          // REBOOT OR DRIFT HANDLING
          // If the hardware counter is significantly lower than our last record, 
          // or if it's the first time tracking (-1), we treat it as a reboot/reset.
          if (lastHardwareSteps == -1 || currentHardwareSteps < lastHardwareSteps) {
            doublePrint("HARDWARE DRIFT DETECTED: Resetting baseline to $currentHardwareSteps");
            await firebaseService.updateLastHardwareSteps(
              uid: uid,
              hardwareSteps: currentHardwareSteps,
            );
            return;
          }

          int deltaSteps = currentHardwareSteps - lastHardwareSteps;

          // DRIFT PROTECTION: Sanity check for massive step jumps (e.g. sensor glitches)
          // Rejecting deltas > 5000 in a single event as likely unrealistic drift.
          if (deltaSteps > 5000) {
             doublePrint("ANOMALOUS DRIFT REJECTED: +$deltaSteps steps ignored.");
             await firebaseService.updateLastHardwareSteps(
              uid: uid,
              hardwareSteps: currentHardwareSteps,
            );
            return;
          }

          if (deltaSteps > 0) {
            // Update base metrics and physical telemetry
            await firebaseService.updateDailyPhysicalStats(
              uid, 
              deltaSteps, 
              deltaSteps * 0.04, 
              deltaSteps * 0.00075
            );
            await firebaseService.logHourlyActivity(uid, deltaSteps);
            
            // Push delta to live gameplay service for RPG pulses and UI updates
            PedometerService().registerSteps(deltaSteps, playerContext: player);
            
            // Sync to team if applicable
            if (player.isInTeam && player.teamId != null) {
              await firebaseService.updateTeamSteps(
                teamId: player.teamId!,
                stepsToAdd: deltaSteps,
              );

              // Update relay progress if this player is the current player
              final challenge = await challengeController.getTeamRelay(player.teamId!).first;
              if (challenge != null && challenge.isActive && challenge.currentPlayerId == uid) {
                await challengeController.updateRelayProgress(player.teamId!, deltaSteps);
              }
            }

            // Sync hardware baseline to cloud
            await firebaseService.updateLastHardwareSteps(
              uid: uid,
              hardwareSteps: currentHardwareSteps,
            );

            lastSyncTime = DateTime.now();

            // Process XP increments (1 XP per 10 steps)
            int xpGain = deltaSteps ~/ 10;
            if (xpGain > 0) {
              await firebaseService.incrementXP(uid: uid, xpToAdd: xpGain);
            }

            // CONTRIBUTE TO GLOBAL OPS
            await firebaseService.contributeToGlobalEvent(deltaSteps);

            doublePrint("HYBRID SYNC: +$deltaSteps steps processed via Hardware Delta.");
          }
        } catch (e) {
          doublePrint("SYNC ERROR: $e");
        } finally {
          _isProcessing = false;
        }
      },
      onError: (error) => doublePrint("PEDOMETER FAULT: $error"),
    );
  }

  void stopTracking() {
    stepStream?.cancel();
    stepStream = null;
    _isProcessing = false;
  }

  void doublePrint(String message) {
    debugPrint("[TELEMETRY] $message");
  }
}
