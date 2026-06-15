class AntiCheatService {

  int warnings = 0;

  int trustScore = 100;

  int leaderboardPoints = 1000;

  bool captureBlocked = false;

  // =========================
  // VEHICLE DETECTION
  // =========================

  bool isVehicle(double speed) {
    return speed > 15.0;
  }

  // =========================
  // WALKING CHECK
  // =========================

  bool isWalking(double speed) {
    // Widened threshold to 0.1 - 15.0 km/h for better detection
    return speed >= 0.1 &&
        speed < 15.0;
  }

  // =========================
  // TELEPORT DETECTION
  // =========================

  bool isTeleportJump(
      double distance, double timeSeconds) {
    if (timeSeconds <= 0) return false;
    double speed = distance / timeSeconds;
    // Over 150 m/s (540 km/h) is definitely suspicious for a fitness app
    return speed > 150 || distance > 1000;
  }

  // =========================
  // APPLY VEHICLE WARNING
  // =========================

  void applyVehicleWarning() {

    warnings++;

    trustScore -= 10;

    captureBlocked = true;

    if (trustScore < 0) {
      trustScore = 0;
    }

    // PENALTY
    if (warnings >= 3) {

      leaderboardPoints -= 100;

      warnings = 0;

      if (leaderboardPoints < 0) {

        leaderboardPoints = 0;
      }
    }
  }

  // =========================
  // APPLY TELEPORT PENALTY
  // =========================

  void applyTeleportPenalty() {

    trustScore -= 20;

    if (trustScore < 0) {

      trustScore = 0;
    }
  }

  // =========================
  // RESET BLOCK
  // =========================

  void resetCaptureBlock() {

    captureBlocked = false;
  }

  // =========================
  // TRUST LEVEL
  // =========================

  String getTrustLevel() {

    if (trustScore >= 90) {
      return "Trusted";
    }

    if (trustScore >= 70) {
      return "Normal";
    }

    if (trustScore >= 40) {
      return "Suspicious";
    }

    return "Cheater";
  }

  // =========================
  // PLAYER STATUS
  // =========================

  String getMovementStatus(
      double speed) {

    if (speed < 0.1) {

      return "🧍 Standing";
    }

    if (speed >= 0.1 &&
        speed < 15.0) {

      return "🚶 Walking";
    }

    return "🚗 Vehicle";
  }

  // =========================
  // CAN CAPTURE
  // =========================

  bool canCapture({

    required bool isWalking,

    required bool realWalking,
  }) {

    return isWalking &&
        realWalking &&
        !captureBlocked;
  }
}