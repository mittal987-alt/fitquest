import 'dart:async';
import 'package:pedometer/pedometer.dart';

class PedometerService {
  static final PedometerService _instance = PedometerService._internal();
  factory PedometerService() => _instance;
  PedometerService._internal();

  StreamSubscription<StepCount>? _stepStreamSub;

  int _systemStepsOffset = -1; // Calibrates hardware steps since device reboot
  int totalSteps = 0;
  int previousSteps = 0;
  DateTime lastStepTime = DateTime.now().subtract(const Duration(minutes: 5));

  int get steps => totalSteps;

  // ==========================================
  // HARDWARE EVENT CAPTURE STREAMS
  // ==========================================

  Stream<StepCount> getStepStream() {
    return Pedometer.stepCountStream;
  }

  void startListening() {
    if (_stepStreamSub != null) return;
    _stepStreamSub = Pedometer.stepCountStream.listen(updateSteps);
  }

  void stopListening() {
    _stepStreamSub?.cancel();
    _stepStreamSub = null;
  }

  void updateSteps(StepCount event) {
    // Calibrate baseline on initial event to counter boot step pollution
    if (_systemStepsOffset == -1) {
      _systemStepsOffset = event.steps;
    }

    int sessionSteps = event.steps - _systemStepsOffset;

    if (sessionSteps > totalSteps) {
      lastStepTime = DateTime.now();
    }

    previousSteps = totalSteps;
    totalSteps = sessionSteps;
  }

  // ==========================================
  // METRICS & ANALYSIS MATRIX
  // ==========================================

  bool isRealWalking() {
    // Validates true if a telemetry event occurred within the past 15 seconds
    return DateTime.now().difference(lastStepTime).inSeconds < 15;
  }

  int getStepDifference() {
    return totalSteps - previousSteps;
  }

  double calculateCalories() {
    return totalSteps * 0.04;
  }

  double calculateDistanceKm() {
    return totalSteps * 0.0008;
  }

  double getGoalProgress({int dailyGoal = 10000}) {
    if (dailyGoal <= 0) return 0.0;
    return totalSteps / dailyGoal;
  }

  // ==========================================
  // EVALUATION LEVELS (TACTICAL HUB THEME)
  // ==========================================

  int getLevel() {
    return (totalSteps / 2000).floor() + 1;
  }

  String getFitnessLevel() {
    if (totalSteps < 3000) return "RECRUIT / BEGINNER";
    if (totalSteps < 7000) return "ACTIVE OPERATOR";
    if (totalSteps < 12000) return "FIT VETERAN";
    return "APEX ATHLETE";
  }

  // ==========================================
  // RESET SEQUENCE
  // ==========================================

  void reset() {
    _systemStepsOffset = -1; // Recalibrates next hardware frame broadcast
    totalSteps = 0;
    previousSteps = 0;
  }
}