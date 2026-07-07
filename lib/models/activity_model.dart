class ActivityModel {
  final String tier; // "RESTORATIVE", "ACTIVE", "ELITE"
  final int durationMinutes;
  final int restIntervalSeconds;
  final double xpMultiplier;
  final double raidDamageMultiplier;
  final List<String> recommendedExercises;

  ActivityModel({
    required this.tier,
    required this.durationMinutes,
    required this.restIntervalSeconds,
    required this.xpMultiplier,
    required this.raidDamageMultiplier,
    required this.recommendedExercises,
  });

  factory ActivityModel.fromBmiAndGoal(double? bmi, String? goal) {
    // Default values
    String tier = "ACTIVE";
    int duration = 30;
    int rest = 60;
    double xpMult = 1.5;
    double raidMult = 1.3;
    List<String> exercises = ["Pushups", "Squats", "Plank"];

    // BMI Base Logic
    if (bmi != null) {
      if (bmi >= 30.0) {
        tier = "RESTORATIVE";
        duration = 20;
        rest = 90;
        xpMult = 1.2;
        raidMult = 1.0;
        exercises = ["Bodyweight Squats", "Wall Pushups", "Plank (Knees)"];
      } else if (bmi < 25.0) {
        tier = "ELITE";
        duration = 50;
        rest = 45;
        xpMult = 2.2;
        raidMult = 1.75;
        exercises = ["Burpees", "Weighted Squats", "Pull-ups"];
      }
    }

    // Goal-Based Refinement (Heuristic ML Engine)
    if (goal == "weight_loss") {
      duration = (duration * 1.2).toInt();
      xpMult += 0.2;
      exercises.addAll(["Mountain Climbers", "Jumping Jacks"]);
    } else if (goal == "muscle_gain") {
      rest = (rest * 1.5).toInt();
      raidMult += 0.25;
      exercises.addAll(["Diamond Pushups", "Lunges"]);
    } else if (goal == "endurance") {
      duration = (duration * 1.5).toInt();
      rest = (rest * 0.8).toInt();
      exercises.addAll(["High Knees", "Shadow Boxing"]);
    }

    return ActivityModel(
      tier: tier,
      durationMinutes: duration,
      restIntervalSeconds: rest,
      xpMultiplier: xpMult,
      raidDamageMultiplier: raidMult,
      recommendedExercises: exercises.toSet().toList(), // Deduplicate
    );
  }

  factory ActivityModel.fromBmi(double? bmi) {
    return ActivityModel.fromBmiAndGoal(bmi, null);
  }
}