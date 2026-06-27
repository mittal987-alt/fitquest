import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import '../models/player_model.dart';

class StepSyncService {
  static final StepSyncService _instance = StepSyncService._internal();
  factory StepSyncService() => _instance;
  StepSyncService._internal();

  final FirebaseService firebaseService = FirebaseService();
  StreamSubscription<StepCount>? stepStream;

  int? lastStepCount;
  int pendingXpSteps = 0;
  DateTime? lastSyncTime;
  bool initialized = false;
  bool _isProcessing = false; // Concurrency protection lock flag
  PlayerModel? cachedPlayer;

  void updateConfig(PlayerModel? player) {
    cachedPlayer = player;
  }

  // ==========================================
  // START BACKGROUND SYNC CHANNEL
  // ==========================================

  void startTracking() {
    if (stepStream != null) return;

    stepStream = Pedometer.stepCountStream.listen(
            (StepCount event) async {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) return;

          // Prevent race-condition data overrides if previous write loop is pending
          if (_isProcessing) {
            doublePrint("TELEMETRY ALERT: Hardware frame dropped. Cloud sync loop active.");
            return;
          }

          _isProcessing = true;

          try {
            // Initialize tracking session baselines on first system execution frame
            if (!initialized) {
              lastStepCount = event.steps;
              cachedPlayer = await firebaseService.getPlayer(uid);
              initialized = true;
              _isProcessing = false;
              return;
            }

            int stepsToAdd = event.steps - (lastStepCount ?? event.steps);

            if (stepsToAdd <= 0) {
              lastStepCount = event.steps;
              _isProcessing = false;
              return;
            }

            // Instantly cache baseline before dispatching async network writes
            lastStepCount = event.steps;
            lastSyncTime = DateTime.now();

            // 1. UPDATE HARDWARE STRIDE VECTOR TO CLOUD METRICS
            await firebaseService.updateSteps(
              uid: uid,
              stepsToAdd: stepsToAdd,
            );

            // 2. DISPATCH COHORT TOTAL ALLOCATIONS IF LINKED TO SQUAD
            if (cachedPlayer != null && cachedPlayer!.isInTeam && cachedPlayer!.teamId != null) {
              await firebaseService.updateTeamSteps(
                teamId: cachedPlayer!.teamId!,
                stepsToAdd: stepsToAdd,
              );
            }

            // 3. COMPUTE DYNAMIC EXPERIENCE COEFFICIENTS
            pendingXpSteps += stepsToAdd;

            if (pendingXpSteps >= 10) {
              int xpGain = pendingXpSteps ~/ 10;
              pendingXpSteps = pendingXpSteps % 10;

              await firebaseService.incrementXP(
                uid: uid,
                xpToAdd: xpGain,
              );

              // Re-fetch current model to calculate precise milestone bounds
              cachedPlayer = await firebaseService.getPlayer(uid);

              if (cachedPlayer != null) {
                int calculatedLevel = (cachedPlayer!.xp ~/ 1000) + 1;

                if (calculatedLevel > cachedPlayer!.level) {
                  await firebaseService.updateLevel(
                    uid: uid,
                    level: calculatedLevel,
                  );
                }
              }
            }
          } catch (e) {
            doublePrint("SYNCHRONIZATION ERROR ENCOUNTERED: $e");
          } finally {
            _isProcessing = false; // Safely release system operational lock
          }
        },
        onError: (error) {
          doublePrint("HARDWARE PEDOMETER INTERFACE FAULT: $error");
        }
    );
  }

  // ==========================================
  // STOP BACKGROUND SYNC CHANNEL
  // ==========================================

  void stopTracking() {
    stepStream?.cancel();
    stepStream = null;
    initialized = false;
    _isProcessing = false;
    lastStepCount = null;
  }

  void doublePrint(String message) {
    // Utility log mapping matching cyberpunk system terminal protocols
    assert(() {
      print("[SQUAD CORE ENGINE] -> $message");
      return true;
    }());
  }
}