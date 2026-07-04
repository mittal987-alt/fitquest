import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:pedometer/pedometer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import '../models/player_model.dart';
import '../controller/relay_controller.dart';

class StepSyncService {
  static final StepSyncService _instance = StepSyncService._internal();
  factory StepSyncService() => _instance;
  StepSyncService._internal();

  final FirebaseService firebaseService = FirebaseService();
  final RelayController relayController = RelayController();
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

          // Handle first-time initialization or device reboots (where hardware steps < last stored)
          if (lastHardwareSteps == -1 || currentHardwareSteps < lastHardwareSteps) {
            await firebaseService.updateLastHardwareSteps(
              uid: uid,
              hardwareSteps: currentHardwareSteps,
            );
            return;
          }

          int deltaSteps = currentHardwareSteps - lastHardwareSteps;

          if (deltaSteps > 0) {
            // Update base metrics
            await firebaseService.updateSteps(uid: uid, stepsToAdd: deltaSteps);
            
            // Sync to team if applicable
            if (player.isInTeam && player.teamId != null) {
              await firebaseService.updateTeamSteps(
                teamId: player.teamId!,
                stepsToAdd: deltaSteps,
              );

              // Update relay progress if this player is the current operator
              final relay = await relayController.getTeamRelay(player.teamId!).first;
              if (relay != null && relay.isActive && relay.currentOperatorId == uid) {
                await relayController.updateRelayProgress(player.teamId!, deltaSteps);
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
