class ActivityModel {
  final String tier; // "RESTORATIVE", "ACTIVE", "ELITE"
  final int durationMinutes;
  final int restIntervalSeconds;
  final double xpMultiplier;
  final double raidDamageMultiplier;

  ActivityModel({
    required this.tier,
    required this.durationMinutes,
    required this.restIntervalSeconds,
    required this.xpMultiplier,
    required this.raidDamageMultiplier,
  });

  factory ActivityModel.fromWeight(double weightKg) {
    if (weightKg > 100) {
      return ActivityModel(
        tier: "RESTORATIVE",
        durationMinutes: 20,
        restIntervalSeconds: 90,
        xpMultiplier: 1.0,
        raidDamageMultiplier: 1.0,
      );
    } else if (weightKg > 80) {
      return ActivityModel(
        tier: "ACTIVE",
        durationMinutes: 30,
        restIntervalSeconds: 60,
        xpMultiplier: 1.5,
        raidDamageMultiplier: 1.25,
      );
    } else {
      return ActivityModel(
        tier: "ELITE",
        durationMinutes: 45,
        restIntervalSeconds: 30,
        xpMultiplier: 2.0,
        raidDamageMultiplier: 1.5,
      );
    }
  }
}