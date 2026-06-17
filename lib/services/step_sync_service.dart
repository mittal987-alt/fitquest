import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import '../models/player_model.dart';

class StepSyncService {
  static final StepSyncService _instance =
  StepSyncService._internal();

  factory StepSyncService() => _instance;

  StepSyncService._internal();

  final FirebaseService firebaseService =
  FirebaseService();

  StreamSubscription<StepCount>? stepStream;

  int? lastStepCount;
  int pendingXpSteps = 0;

  bool initialized = false;

  PlayerModel? cachedPlayer;

  void updateConfig(
      PlayerModel? player) {
    cachedPlayer = player;
  }

  // =========================
  // START TRACKING
  // =========================

  void startTracking() {
    if (stepStream != null) return;

    stepStream =
        Pedometer.stepCountStream.listen(

              (StepCount event) async {

            final uid =
                FirebaseAuth.instance
                    .currentUser
                    ?.uid;

            if (uid == null) return;

            print(
              "RAW STEPS: ${event.steps}",
            );

            // First launch

            if (!initialized) {

              lastStepCount =
                  event.steps;

              cachedPlayer =
              await firebaseService
                  .getPlayer(uid);

              initialized = true;

              return;
            }

            int stepsToAdd =
                event.steps -
                    (lastStepCount ??
                        event.steps);

            print(
              "STEPS TO ADD: $stepsToAdd",
            );

            if (stepsToAdd <= 0) {

              lastStepCount =
                  event.steps;

              return;
            }

            lastStepCount =
                event.steps;

            // =====================
            // UPDATE PLAYER STEPS
            // =====================

            await firebaseService
                .updateSteps(
              uid: uid,
              stepsToAdd:
              stepsToAdd,
            );

            print(
              "PLAYER STEPS UPDATED",
            );

            // =====================
            // TEAM STEPS
            // =====================

            if (cachedPlayer !=
                null &&
                cachedPlayer!
                    .isInTeam &&
                cachedPlayer!
                    .teamId !=
                    null) {

              await firebaseService
                  .updateTeamSteps(
                teamId:
                cachedPlayer!
                    .teamId!,
                stepsToAdd:
                stepsToAdd,
              );

              print(
                "TEAM STEPS UPDATED",
              );
            }

            // =====================
            // XP SYSTEM
            // =====================

            pendingXpSteps +=
                stepsToAdd;

            if (pendingXpSteps >=
                10) {

              int xpGain =
                  pendingXpSteps ~/
                      10;

              pendingXpSteps =
                  pendingXpSteps %
                      10;

              await firebaseService
                  .incrementXP(
                uid: uid,
                xpToAdd: xpGain,
              );

              print(
                "XP ADDED: $xpGain",
              );

              cachedPlayer =
              await firebaseService
                  .getPlayer(uid);

              if (cachedPlayer !=
                  null) {

                int newLevel =
                    (cachedPlayer!
                        .xp ~/
                        1000) +
                        1;

                if (newLevel >
                    cachedPlayer!
                        .level) {

                  await firebaseService
                      .updateLevel(
                    uid: uid,
                    level:
                    newLevel,
                  );

                  print(
                    "LEVEL UP: $newLevel",
                  );
                }
              }
            }
          },
        );
  }

  // =========================
  // STOP TRACKING
  // =========================

  void stopTracking() {

    stepStream?.cancel();

    stepStream = null;

    initialized = false;

    lastStepCount = null;
  }
}