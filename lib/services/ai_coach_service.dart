import 'dart:math';
import '../models/player_model.dart';

class AICoachService {
  String generateDailyMotivation(PlayerModel player) {
    final int steps = player.dailySteps;
    final int target = player.dailyStepTarget;
    final double progress = (steps / target).clamp(0.0, 1.0);

    if (progress >= 1.0) {
      return "Objective secured, Strider. You've hit your target. Data suggests you're ready for higher intensity.";
    } else if (progress >= 0.7) {
      return "Final stretch detected. ${target - steps} steps remaining to reach optimal performance.";
    } else if (progress >= 0.4) {
      return "Mid-way point reached. Your pace is consistent. Maintain current output.";
    } else {
      return "Low activity level detected. Initiate movement to optimize your RPG attributes.";
    }
  }

  String getFitnessInsight(PlayerModel player) {
    if (player.bmi != null) {
      double bmi = player.bmi!;
      if (bmi > 25) {
        return "Focusing on Endurance will optimize caloric burn and improve your Strider rank.";
      } else if (bmi < 18.5) {
        return "Increasing Strength through resistance walking will build your combat resilience.";
      }
    }
    return "Balanced progression detected. Continue multi-disciplinary training.";
  }
}
