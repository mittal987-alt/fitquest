class ActivityModel {
  final String tier; // "RESTORATIVE", "ACTIVE", "ELITE"
  final int durationMinutes;
  final int restIntervalSeconds;
  final double xpMultiplier;
  final double raidDamageMultiplier;
  final List<Map<String, String>> exerciseGuide; // Now holds Name + Tip

  ActivityModel({
    required this.tier,
    required this.durationMinutes,
    required this.restIntervalSeconds,
    required this.xpMultiplier,
    required this.raidDamageMultiplier,
    required this.exerciseGuide,
  });

  factory ActivityModel.fromBmiAndGoal(double? bmi, String? goal) {
    // Default values
    String tier = "ACTIVE";
    int duration = 30;
    int rest = 60;
    double xpMult = 1.5;
    double raidMult = 1.3;
    List<Map<String, String>> guide = [
      {"name": "Pushups", "tip": "Keep core tight, back straight."},
      {"name": "Squats", "tip": "Weight on heels, chest up."},
      {"name": "Plank", "tip": "Squeeze glutes, hold steady."}
    ];

    // BMI Base Logic
    if (bmi != null) {
      if (bmi >= 30.0) {
        tier = "RESTORATIVE";
        duration = 20;
        rest = 90;
        xpMult = 1.2;
        raidMult = 1.0;
        guide = [
          {"name": "Bodyweight Squats", "tip": "Control the descent."},
          {"name": "Wall Pushups", "tip": "Keep elbows tucked."},
          {"name": "Plank (Knees)", "tip": "Don't let hips sag."}
        ];
      } else if (bmi < 25.0) {
        tier = "ELITE";
        duration = 50;
        rest = 45;
        xpMult = 2.2;
        raidMult = 1.75;
        guide = [
          {"name": "Burpees", "tip": "Explosive movement."},
          {"name": "Weighted Squats", "tip": "Drive through heels."},
          {"name": "Pull-ups", "tip": "Full range of motion."}
        ];
      }
    }

    // Goal-Based Refinement (Heuristic ML Engine)
    if (goal == "weight_loss") {
      duration = (duration * 1.2).toInt();
      xpMult += 0.2;
      guide.addAll([
        {"name": "Mountain Climbers", "tip": "High intensity, quick feet."},
        {"name": "Jumping Jacks", "tip": "Stay light on your toes."}
      ]);
    } else if (goal == "muscle_gain") {
      rest = (rest * 1.5).toInt();
      raidMult += 0.25;
      guide.addAll([
        {"name": "Diamond Pushups", "tip": "Focus on triceps."},
        {"name": "Lunges", "tip": "Keep torso upright."}
      ]);
    } else if (goal == "endurance") {
      duration = (duration * 1.5).toInt();
      rest = (rest * 0.8).toInt();
      guide.addAll([
        {"name": "High Knees", "tip": "Pump your arms."},
        {"name": "Shadow Boxing", "tip": "Focus on breathing."}
      ]);
    }

    return ActivityModel(
      tier: tier,
      durationMinutes: duration,
      restIntervalSeconds: rest,
      xpMultiplier: xpMult,
      raidDamageMultiplier: raidMult,
      exerciseGuide: guide,
    );
  }

  factory ActivityModel.fromBmi(double? bmi) {
    return ActivityModel.fromBmiAndGoal(bmi, null);
  }
}
