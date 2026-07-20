import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:pedometer/pedometer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_service.dart';
import 'pedometer_service.dart';
import 'location_service.dart';
import '../models/player_model.dart';
import '../controller/tactical_relay_controller.dart';
import '../config/gameplay_rules.dart';

class StepSyncService {
  static final StepSyncService _instance = StepSyncService._internal();
  factory StepSyncService() => _instance;
  StepSyncService._internal();

  final FirebaseService firebaseService = FirebaseService();
  final TacticalRelayController challengeController = TacticalRelayController();
  final LocationService locationService = LocationService();
  final PedometerService pedometerService = PedometerService();
  
  StreamSubscription<StepCount>? stepStream;
  StreamSubscription? _locationSubscription;
  DateTime? lastSyncTime;
  double _currentSpeedKmh = 0.0;

  final _syncStatusController = StreamController<bool>.broadcast();
  Stream<bool> get syncStatusStream => _syncStatusController.stream;

  bool _isProcessing = false;
  PlayerModel? cachedPlayer;
  
  // Local anchor to track steps between cloud sync pulses
  int? _lastLocalHardwareSteps;

  void updateConfig(PlayerModel? player) {
    cachedPlayer = player;
  }

  Future<void> startTracking() async {
    if (stepStream != null) return;

    // REQUEST PERMISSIONS
    Map<Permission, PermissionStatus> statuses = await [
      Permission.activityRecognition,
      Permission.locationWhenInUse,
    ].request();

    if (statuses[Permission.activityRecognition]!.isDenied) {
      doublePrint("PERMISSION DENIED: Steps will not sync.");
      return;
    }

    // Start Location Stream for Speed-based Anti-Cheat
    if (statuses[Permission.locationWhenInUse]!.isGranted) {
      _locationSubscription = locationService.getLocationStream().listen((position) {
        _currentSpeedKmh = locationService.getSpeedKmh(position);
        // doublePrint("SPEED CHECK: ${_currentSpeedKmh.toStringAsFixed(1)} km/h");
      });
    }

    stepStream = Pedometer.stepCountStream.listen(
      (StepCount event) async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        // SPEED-BASED ANTI-CHEAT
        // If speed is > 12 km/h (vehicle range), ignore hardware step increments.
        if (locationService.isVehicle(_currentSpeedKmh)) {
          doublePrint("VEHICLE DETECTED (${_currentSpeedKmh.toStringAsFixed(1)} km/h): Steps suppressed.");
          return;
        }

        if (_isProcessing) return;
        _isProcessing = true;

        try {
          // 1. Use cached player if available to reduce reads, but refresh if it's null
          PlayerModel? player = cachedPlayer;
          if (player == null) {
            player = await firebaseService.getPlayer(uid);
            if (player == null) {
              _isProcessing = false;
              return;
            }
            cachedPlayer = player;
          }

          int currentHardwareSteps = event.steps;
          int lastHardwareSteps = player.lastHardwareStepCount;

          // REBOOT OR DRIFT HANDLING
          if (lastHardwareSteps <= 0 || currentHardwareSteps < lastHardwareSteps) {
            doublePrint("BASELINE ANCHORED: Setting baseline to $currentHardwareSteps.");
            await firebaseService.updateLastHardwareSteps(
              uid: uid,
              hardwareSteps: currentHardwareSteps,
            );
            _lastLocalHardwareSteps = currentHardwareSteps;
            cachedPlayer = player.copyWith(lastHardwareStepCount: currentHardwareSteps);
            _isProcessing = false;
            return;
          }

          int deltaSteps = currentHardwareSteps - lastHardwareSteps;

          // DRIFT PROTECTION
          int driftThreshold = (lastSyncTime == null || DateTime.now().difference(lastSyncTime!).inMinutes > 30) 
              ? 15000 
              : 2000;

          if (deltaSteps > driftThreshold) {
             doublePrint("ANOMALOUS DRIFT REJECTED: +$deltaSteps steps ignored.");
             _showDriftNotification(deltaSteps, driftThreshold, currentHardwareSteps);
             await firebaseService.updateLastHardwareSteps(
              uid: uid,
              hardwareSteps: currentHardwareSteps,
            );
            _lastLocalHardwareSteps = currentHardwareSteps;
            cachedPlayer = player.copyWith(lastHardwareStepCount: currentHardwareSteps);
            _isProcessing = false;
            return;
          }

          // 2. LOCAL ENGINE PULSE (Immediate feedback)
          _lastLocalHardwareSteps ??= lastHardwareSteps;
          int pulseDelta = currentHardwareSteps - _lastLocalHardwareSteps!;
          
          if (pulseDelta > 0) {
            pedometerService.registerSteps(pulseDelta, playerContext: player);
            _lastLocalHardwareSteps = currentHardwareSteps;
            doublePrint("LOCAL PULSE: +$pulseDelta steps processed.");
          }

          // 3. CLOUD SYNC THROTTLE (Limit Firestore writes to once every 30 seconds)
          final now = DateTime.now();
          if (lastSyncTime != null && now.difference(lastSyncTime!).inSeconds < 30) {
            _isProcessing = false;
            return;
          }

          if (deltaSteps > 0) {
            _syncStatusController.add(true);
            
            // Unified Telemetry Sync (Batching multiple field increments including team steps)
            await firebaseService.syncTelemetry(
              uid: uid,
              deltaSteps: deltaSteps,
              currentHardwareSteps: currentHardwareSteps,
              player: player,
            );
            
            // Cross-Document Updates
            if (player.isInTeam && player.teamId != null) {
              final challenge = await challengeController.getTeamRelay(player.teamId!).first;
              if (challenge != null && challenge.isActive && challenge.currentPlayerId == uid) {
                await challengeController.updateRelayProgress(player.teamId!, deltaSteps);
              }

              // Background Raid Damage Contribution
              await firebaseService.contributeRaidDamageFromSteps(
                teamId: player.teamId!,
                uid: uid,
                steps: deltaSteps,
              );
            }

            await firebaseService.contributeToGlobalEvent(uid: uid, steps: deltaSteps);

            lastSyncTime = DateTime.now();
            
            cachedPlayer = player.copyWith(
              lastHardwareStepCount: currentHardwareSteps,
              totalSteps: player.totalSteps + deltaSteps,
              dailySteps: player.dailySteps + deltaSteps,
              weeklySteps: player.weeklySteps + deltaSteps,
              dailyCalories: player.dailyCalories + (deltaSteps * GameplayRules.caloriesPerStep).toInt(),
              dailyDistance: player.dailyDistance + (deltaSteps * GameplayRules.distanceKmPerStep),
              xp: player.xp + (deltaSteps ~/ 10 * player.energyBoostXpMultiplier).toInt(),
              currentStamina: player.currentStamina + (deltaSteps / 1000 * GameplayRules.staminaRefillPerThousandSteps).floor(),
            );

            doublePrint("CLOUD SYNC: +$deltaSteps total steps persisted to Firestore.");
            _syncStatusController.add(false);
          } else {
            lastSyncTime = DateTime.now();
          }
        } catch (e) {
          doublePrint("SYNC ERROR: $e");
          _syncStatusController.add(false);
        } finally {
          _isProcessing = false;
        }
      },
      onError: (error) => doublePrint("PEDOMETER FAULT: $error"),
    );
  }

  void stopTracking() {
    stepStream?.cancel();
    _locationSubscription?.cancel();
    stepStream = null;
    _locationSubscription = null;
    _isProcessing = false;
  }

  void dispose() {
    stepStream?.cancel();
    _locationSubscription?.cancel();
    _syncStatusController.close();
  }

  void reset() {
    lastSyncTime = null;
    _currentSpeedKmh = 0.0;
    _isProcessing = false;
    cachedPlayer = null;
    _lastLocalHardwareSteps = null;
    debugPrint("[TELEMETRY] StepSyncService reset.");
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
