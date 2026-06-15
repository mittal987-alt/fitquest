import 'dart:async';

import 'package:pedometer/pedometer.dart';

class PedometerService {
  static final PedometerService _instance = PedometerService._internal();
  factory PedometerService() => _instance;
  PedometerService._internal();

  StreamSubscription<StepCount>?
  stepStream;

  int totalSteps = 0;
  int previousSteps = 0;
  DateTime lastStepTime = DateTime.now().subtract(const Duration(minutes: 5));
  int get steps => totalSteps;

  // =========================
  // STEP STREAM
  // =========================

  Stream<StepCount>
  getStepStream() {

    return Pedometer
        .stepCountStream;
  }

  // =========================
  // START LISTENING
  // =========================

  void startListening() {
    if (stepStream != null) return;
    stepStream = Pedometer.stepCountStream.listen(updateSteps);
  }

  // =========================
  // STOP LISTENING
  // =========================

  void stopListening() {

    stepStream?.cancel();
  }

  // =========================
  // UPDATE STEPS
  // =========================

  void updateSteps(
      StepCount event) {

    if (event.steps > totalSteps) {
      lastStepTime = DateTime.now();
    }

    previousSteps = totalSteps;

    totalSteps = event.steps;
  }

  // =========================
  // REAL WALKING CHECK
  // =========================

  bool isRealWalking() {
    // If we received a step update in the last 15 seconds, we are walking
    return DateTime.now().difference(lastStepTime).inSeconds < 15;
  }

  // =========================
  // STEP DIFFERENCE
  // =========================

  int getStepDifference() {

    return totalSteps -
        previousSteps;
  }

  // =========================
  // CALORIES
  // =========================

  double calculateCalories() {

    return totalSteps * 0.04;
  }

  // =========================
  // DISTANCE
  // =========================

  double calculateDistanceKm() {

    return totalSteps * 0.0008;
  }

  // =========================
  // DAILY GOAL %
  // =========================

  double getGoalProgress({

    int dailyGoal = 10000,
  }) {

    return totalSteps /
        dailyGoal;
  }

  // =========================
  // FITNESS LEVEL
  // =========================

  int getLevel() {

    return (totalSteps / 2000)
        .floor() + 1;
  }

  String getFitnessLevel() {

    if (totalSteps < 3000) {
      return "Beginner";
    }

    if (totalSteps < 7000) {
      return "Active";
    }

    if (totalSteps < 12000) {
      return "Fit";
    }

    return "Athlete";
  }

  // =========================
  // RESET
  // =========================

  void reset() {

    totalSteps = 0;

    previousSteps = 0;
  }
}