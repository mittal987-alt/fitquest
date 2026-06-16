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
  int _pendingXpSteps = 0;
  bool initialized = false;
  PlayerModel? _cachedPlayer;

  // Update the cached player to ensure team steps are synced correctly
  void updateConfig(PlayerModel? player) {
    _cachedPlayer = player;
  }

  // =========================
  // START STEP TRACKING
  // =========================

  void startTracking() {
    if (stepStream != null) return;
    stepStream = Pedometer.stepCountStream.listen((StepCount event) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      if (!initialized) {
        lastStepCount = event.steps;
        // Fetch player once at start to know team status
        _cachedPlayer = await firebaseService.getPlayer(uid);
        initialized = true;
        return;
      }

      int stepsToAdd = event.steps - (lastStepCount ?? event.steps);
      
      // Handle potential step counter reset (e.g., phone reboot)
      if (stepsToAdd < 0) {
        lastStepCount = event.steps;
        return;
      }

      if (stepsToAdd == 0) return;

      lastStepCount = event.steps;

      // Batch updates to every 5 steps to reduce Firestore writes while remaining "real-time"
      if (stepsToAdd >= 5) {
        // 1. Update Player Total Steps (Incrementally)
        await firebaseService.updateSteps(
          uid: uid,
          stepsToAdd: stepsToAdd,
        );

        // 2. Update Team Steps if applicable
        if (_cachedPlayer != null && _cachedPlayer!.isInTeam && _cachedPlayer!.teamId != null) {
          await firebaseService.updateTeamSteps(
            teamId: _cachedPlayer!.teamId!,
            stepsToAdd: stepsToAdd,
          );
        }
      }

      // 3. XP & Level System - Accumulate until we have at least 10 steps to grant 1 XP
      _pendingXpSteps += stepsToAdd;
      if (_pendingXpSteps >= 10) {
        int xpGain = _pendingXpSteps ~/ 10;
        _pendingXpSteps %= 10;

        await firebaseService.incrementXP(uid: uid, xpToAdd: xpGain);
        
        // Re-fetch player occasionally to check for level up
        // or calculate it locally if we trust our cache
        if (_cachedPlayer != null) {
          int newXp = _cachedPlayer!.xp + xpGain;
          int newLevel = (newXp ~/ 1000) + 1;

          if (newLevel > _cachedPlayer!.level) {
            await firebaseService.updateLevel(uid: uid, level: newLevel);
            // Refresh cache after level up
            _cachedPlayer = await firebaseService.getPlayer(uid);
          } else {
            // Just update local XP to keep track
            _cachedPlayer = PlayerModel(
              uid: _cachedPlayer!.uid,
              name: _cachedPlayer!.name,
              isInTeam: _cachedPlayer!.isInTeam,
              email: _cachedPlayer!.email,
              team: _cachedPlayer!.team,
              teamId: _cachedPlayer!.teamId,
              totalSteps: _cachedPlayer!.totalSteps + stepsToAdd,
              totalLand: _cachedPlayer!.totalLand,
              trustScore: _cachedPlayer!.trustScore,
              level: _cachedPlayer!.level,
              xp: newXp,
              avatar: _cachedPlayer!.avatar,
              lastTeamAction: _cachedPlayer!.lastTeamAction,
              streakCount: _cachedPlayer!.streakCount,
              lastActiveDate: _cachedPlayer!.lastActiveDate,
              claimedQuests: _cachedPlayer!.claimedQuests,
              activePowerUps: _cachedPlayer!.activePowerUps,
            );
          }
        } else {
          // If for some reason cache is null, fetch it
          _cachedPlayer = await firebaseService.getPlayer(uid);
        }
      }
    });
  }

  // =========================
  // STOP TRACKING
  // =========================

  void stopTracking() {
    stepStream?.cancel();
    initialized = false;
  }
}
