class ActivityModel {
  final String tier; // "RESTORATIVE", "ACTIVE", "ELITE"
  final int durationMinutes;
  final int restIntervalSeconds;
  final double xpMultiplier;
  final double raidDamageMultiplier;
  final List<Map<String, String>> exerciseGuide; // Now holds Name + Tip + Target

  ActivityModel({
    required this.tier,
    required this.durationMinutes,
    required this.restIntervalSeconds,
    required this.xpMultiplier,
    required this.raidDamageMultiplier,
    required this.exerciseGuide,
  });

  factory ActivityModel.fromBmiAndGoal(double? bmi, String? goal, {int trustScore = 100, int level = 1}) {
    // Default values
    String tier = "ACTIVE";
    int duration = 30;
    int rest = 60;
    double xpMult = 1.5;
    double raidMult = 6.0; 
    List<Map<String, String>> guide = [
      {"name": "Pushups", "tip": "Keep core tight, back straight.", "target": "15 REPS"},
      {"name": "Squats", "tip": "Weight on heels, chest up.", "target": "20 REPS"},
      {"name": "Plank", "tip": "Squeeze glutes, hold steady.", "target": "45 SEC"}
    ];

    // 1. PHYSICAL BASELINE (BMI Logic)
    if (bmi != null) {
      if (bmi >= 30.0) {
        tier = "RESTORATIVE";
        duration = 20;
        rest = 90;
        xpMult = 1.2;
        raidMult = 4.5;
        guide = [
          {"name": "Bodyweight Squats", "tip": "Control the descent.", "target": "10 REPS"},
          {"name": "Wall Pushups", "tip": "Keep elbows tucked.", "target": "10 REPS"},
          {"name": "Plank (Knees)", "tip": "Don't let hips sag.", "target": "30 SEC"}
        ];
      } else if (bmi < 25.0) {
        tier = "ELITE";
        duration = 50;
        rest = 45;
        xpMult = 2.2;
        raidMult = 11.5; 
        guide = [
          {"name": "Burpees", "tip": "Explosive movement.", "target": "20 REPS"},
          {"name": "Weighted Squats", "tip": "Drive through heels.", "target": "25 REPS"},
          {"name": "Pull-ups", "tip": "Full range of motion.", "target": "8 REPS"}
        ];
      }
    }

    // Adjust targets based on level
    if (level > 10) {
      for (var exercise in guide) {
        if (exercise["target"]!.contains("REPS")) {
          int reps = int.parse(exercise["target"]!.split(" ")[0]);
          exercise["target"] = "${reps + (level ~/ 5)} REPS";
        } else if (exercise["target"]!.contains("SEC")) {
          int sec = int.parse(exercise["target"]!.split(" ")[0]);
          exercise["target"] = "${sec + (level * 2)} SEC";
        }
      }
    }

    // 2. NEURAL ADAPTATION (Consistency & Level Scaling)
    // The "ML" engine rewards high trust and level with "Overclocked" multipliers
    double neuralFactor = (trustScore / 100.0) + (level / 50.0);
    xpMult *= neuralFactor.clamp(0.8, 1.5);
    raidMult *= neuralFactor.clamp(0.8, 1.5);

    if (trustScore > 95 && level > 5) {
      // "VETERAN" Overclocking
      duration = (duration * 1.1).toInt();
      xpMult += 0.3;
    }

    // 3. STRATEGIC GOAL REFINEMENT
    if (goal == "weight_loss") {
      duration = (duration * 1.2).toInt();
      xpMult += 0.2;
      guide.addAll([
        {"name": "Mountain Climbers", "tip": "High intensity, quick feet.", "target": "40 SEC"},
        {"name": "Jumping Jacks", "tip": "Stay light on your toes.", "target": "50 REPS"}
      ]);
    } else if (goal == "muscle_gain") {
      rest = (rest * 1.5).toInt();
      raidMult += 0.25;
      guide.addAll([
        {"name": "Diamond Pushups", "tip": "Focus on triceps.", "target": "12 REPS"},
        {"name": "Lunges", "tip": "Keep torso upright.", "target": "20 REPS"}
      ]);
    } else if (goal == "endurance") {
      duration = (duration * 1.5).toInt();
      rest = (rest * 0.8).toInt();
      guide.addAll([
        {"name": "High Knees", "tip": "Pump your arms.", "target": "60 SEC"},
        {"name": "Shadow Boxing", "tip": "Focus on breathing.", "target": "2 MIN"}
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