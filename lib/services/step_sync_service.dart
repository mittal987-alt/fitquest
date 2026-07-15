import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:pedometer/pedometer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_service.dart';
import 'pedometer_service.dart';
import '../models/player_model.dart';
import '../controller/tactical_relay_controller.dart';
import '../config/gameplay_rules.dart';

class StepSyncService {
  static final StepSyncService _instance = StepSyncService._internal();
  factory StepSyncService() => _instance;
  StepSyncService._internal();

  final FirebaseService firebaseService = FirebaseService();
  final TacticalRelayController challengeController = TacticalRelayController();
  StreamSubscription<StepCount>? stepStream;
  DateTime? lastSyncTime;

  final _syncStatusController = StreamController<bool>.broadcast();
  Stream<bool> get syncStatusStream => _syncStatusController.stream;

  bool _isProcessing = false;
  PlayerModel? cachedPlayer;

  void updateConfig(PlayerModel? player) {
    cachedPlayer = player;
  }

  Future<void> startTracking() async {
    if (stepStream != null) return;

    // REQUEST PERMISSIONS
    var status = await Permission.activityRecognition.request();
    if (status.isDenied) {
      doublePrint("PERMISSION DENIED: Steps will not sync.");
      return;
    }

    stepStream = Pedometer.stepCountStream.listen(
      (StepCount event) async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        if (_isProcessing) return;
        _isProcessing = true;
        _syncStatusController.add(true);

        try {
          // 1. Use cached player if available to reduce reads, but refresh if it's null
          PlayerModel? player = cachedPlayer;
          if (player == null) {
            player = await firebaseService.getPlayer(uid);
            if (player == null) return;
            cachedPlayer = player;
          }

          int currentHardwareSteps = event.steps;
          int lastHardwareSteps = player.lastHardwareStepCount;

          // REBOOT OR DRIFT HANDLING
          // If lastHardwareSteps is 0 (uninitialized) or the phone rebooted (count dropped),
          // we anchor to the current count instead of calculating a massive fake delta.
          if (lastHardwareSteps <= 0 || currentHardwareSteps < lastHardwareSteps) {
            doublePrint("BASELINE ANCHORED: Setting baseline to $currentHardwareSteps to prevent ghost steps.");
            await firebaseService.updateLastHardwareSteps(
              uid: uid,
              hardwareSteps: currentHardwareSteps,
            );
            // Update cache so the next event starts from this anchor
            cachedPlayer = player.copyWith(lastHardwareStepCount: currentHardwareSteps);
            return;
          }

          int deltaSteps = currentHardwareSteps - lastHardwareSteps;

          // DRIFT PROTECTION: Sanity check for massive step jumps
          // If the app was closed for a while, we allow larger deltas (e.g., 10k steps)
          // otherwise we stick to a reasonable 2000 step cap per individual event pulse.
          int driftThreshold = (lastSyncTime == null || DateTime.now().difference(lastSyncTime!).inMinutes > 30) 
              ? 15000 
              : 2000;

          if (deltaSteps > driftThreshold) {
             doublePrint("ANOMALOUS DRIFT REJECTED: +$deltaSteps steps ignored (Threshold: $driftThreshold).");
             _showDriftNotification(deltaSteps, driftThreshold, currentHardwareSteps);
             await firebaseService.updateLastHardwareSteps(
              uid: uid,
              hardwareSteps: currentHardwareSteps,
            );
            cachedPlayer = player.copyWith(lastHardwareStepCount: currentHardwareSteps);
            return;
          }

          if (deltaSteps > 0) {
            // Unified Telemetry Sync (Batching multiple field increments)
            final updates = await firebaseService.syncTelemetry(
              uid: uid,
              deltaSteps: deltaSteps,
              currentHardwareSteps: currentHardwareSteps,
              player: player,
            );

            // Push delta to live gameplay service for RPG pulses and UI updates
            PedometerService().registerSteps(deltaSteps, playerContext: player);
            
            // Cross-Document Updates (These remain separate as they target different collections)
            if (player.isInTeam && player.teamId != null) {
              await firebaseService.updateTeamSteps(
                teamId: player.teamId!,
                stepsToAdd: deltaSteps,
              );

              final challenge = await challengeController.getTeamRelay(player.teamId!).first;
              if (challenge != null && challenge.isActive && challenge.currentPlayerId == uid) {
                await challengeController.updateRelayProgress(player.teamId!, deltaSteps);
              }
            }

            // CONTRIBUTE TO GLOBAL OPS
            await firebaseService.contributeToGlobalEvent(deltaSteps);

            lastSyncTime = DateTime.now();
            
            // Extract the real incremented values from the update map if possible, 
            // though FieldValue.increment makes local prediction safer here.
            cachedPlayer = player.copyWith(
              lastHardwareStepCount: currentHardwareSteps,
              totalSteps: player.totalSteps + deltaSteps,
              dailySteps: player.dailySteps + deltaSteps,
              dailyCalories: player.dailyCalories + (deltaSteps * GameplayRules.caloriesPerStep).toInt(),
              dailyDistance: player.dailyDistance + (deltaSteps * GameplayRules.distanceKmPerStep),
              xp: player.xp + (deltaSteps ~/ 10 * player.energyBoostXpMultiplier).toInt(),
            );

            doublePrint("HYBRID SYNC: +$deltaSteps steps processed via Hardware Delta.");
          } else {
            // Even if delta is 0, update lastSyncTime to maintain the drift window
            lastSyncTime = DateTime.now();
          }
        } catch (e) {
          doublePrint("SYNC ERROR: $e");
        } finally {
          _isProcessing = false;
          _syncStatusController.add(false);
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

  void dispose() {
    stepStream?.cancel();
    _syncStatusController.close();
  }

  void doublePrint(String message) {
    debugPrint("[TELEMETRY] $message");
  }

  void _showDriftNotification(int delta, int threshold, int hardware) {
    // We can't use ScaffoldMessenger here easily without context, 
    // but we can add a stream event for the UI to listen to.
    _driftEventController.add(DriftEvent(
      delta: delta,
      threshold: threshold,
      hardwareSteps: hardware,
    ));
  }

  final _driftEventController = StreamController<DriftEvent>.broadcast();
  Stream<DriftEvent> get driftEventStream => _driftEventController.stream;
}

class DriftEvent {
  final int delta;
  final int threshold;
  final int hardwareSteps;
  DriftEvent({required this.delta, required this.threshold, required this.hardwareSteps});
}
