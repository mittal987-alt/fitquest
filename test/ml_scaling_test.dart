import 'package:flutter_test/flutter_test.dart';
import '../lib/models/activity_model.dart';

void main() {
  group('ML Scaling & Overclocking Logic', () {
    test('Overweight BMI (>= 30) triggers RESTORATIVE tier and higher rest', () {
      final model = ActivityModel.fromBmiAndGoal(32.0, "maintenance", trustScore: 100, level: 1);
      
      expect(model.tier, "RESTORATIVE");
      expect(model.durationMinutes, 20);
      expect(model.restIntervalSeconds, 90);
      // neuralFactor = (100/100) + (1/50) = 1.02
      // 1.2 * 1.02 = 1.224
      expect(model.xpMultiplier, closeTo(1.224, 0.001));
    });

    test('Healthy BMI (< 25) triggers ELITE tier with aggressive rest', () {
      final model = ActivityModel.fromBmiAndGoal(22.0, "maintenance", trustScore: 100, level: 1);
      
      expect(model.tier, "ELITE");
      expect(model.durationMinutes, 50);
      expect(model.restIntervalSeconds, 45);
      // neuralFactor = 1.02
      // 2.2 * 1.02 = 2.244
      expect(model.xpMultiplier, closeTo(2.244, 0.001));
    });

    test('Low Trust Score (< 80) reduces XP multipliers (Neural Adaptation)', () {
      // Base for healthy BMI is 2.2x
      // neuralFactor = (50/100) + (1/50) = 0.5 + 0.02 = 0.52 -> clamped to 0.8
      // 2.2 * 0.8 = 1.76
      final lowTrust = ActivityModel.fromBmiAndGoal(22.0, "maintenance", trustScore: 50, level: 1);
      expect(lowTrust.xpMultiplier, lessThan(2.2));
      expect(lowTrust.xpMultiplier, closeTo(1.76, 0.01));
    });

    test('High Trust + High Level triggers VETERAN Overclocking', () {
      // Base for healthy BMI: 2.2x, 50 mins
      // neuralFactor = (100/100) + (25/50) = 1.0 + 0.5 = 1.5
      // 2.2 * 1.5 = 3.3
      // Overclocking: duration * 1.1 = 55, xpMult + 0.3 = 3.6
      final veteran = ActivityModel.fromBmiAndGoal(22.0, "maintenance", trustScore: 100, level: 25);
      
      expect(veteran.durationMinutes, 55);
      expect(veteran.xpMultiplier, closeTo(3.6, 0.01));
    });

    test('Weight Loss goal increases duration and XP boost', () {
      // Base: RESTORATIVE (20 mins, 1.2x XP)
      // neuralFactor = 1.02
      // Goal "weight_loss": duration * 1.2 = 24, (1.2 * 1.02) + 0.2 = 1.224 + 0.2 = 1.424
      final weightLoss = ActivityModel.fromBmiAndGoal(32.0, "weight_loss", trustScore: 100, level: 1);
      
      expect(weightLoss.durationMinutes, 24);
      expect(weightLoss.xpMultiplier, closeTo(1.424, 0.001));
      
      bool hasCardio = weightLoss.exerciseGuide.any((e) => e['name'] == "Mountain Climbers");
      expect(hasCardio, true);
    });

    test('Muscle Gain goal increases rest and Raid Damage', () {
      // Base: ELITE (45s rest, 1.75x Raid)
      // neuralFactor = 1.02
      // Goal "muscle_gain": rest * 1.5 = 67, (1.75 * 1.02) + 0.25 = 1.785 + 0.25 = 2.035
      final muscleGain = ActivityModel.fromBmiAndGoal(22.0, "muscle_gain", trustScore: 100, level: 1);
      
      expect(muscleGain.restIntervalSeconds, 67);
      expect(muscleGain.raidDamageMultiplier, closeTo(2.035, 0.001));
    });
  });
}
