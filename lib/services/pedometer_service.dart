import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import '../models/player_model.dart';
import '../models/gear_model.dart';
import '../config/gameplay_rules.dart';

class TacticalPulse {
  final int steps;
  final double raidDamage;
  final double scanProgress;
  final int apRegained;
  final String? discoveredMaterial;
  final double velocityMultiplier;
  final bool isAheadOfGhost;

  TacticalPulse({
    required this.steps,
    required this.raidDamage,
    required this.scanProgress,
    required this.apRegained,
    this.discoveredMaterial,
    this.velocityMultiplier = 1.0,
    this.isAheadOfGhost = false,
  });
}

class GhostStatus {
  final int stepsAhead;
  final bool isAhead;
  final int ghostTarget;
  final double velocityIndex;

  GhostStatus({
    required this.stepsAhead,
    required this.isAhead,
    required this.ghostTarget,
    required this.velocityIndex,
  });
}

class StepSegment {
  final int hour;
  final int stepDelta;
  final DateTime timestamp;

  StepSegment({
    required this.hour,
    required this.stepDelta,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'hour': hour,
      'stepDelta': stepDelta,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class PedometerService {
  static final PedometerService _instance = PedometerService._internal();
  factory PedometerService() => _instance;
  PedometerService._internal();

  final StreamController<int> _stepStreamController = StreamController<int>.broadcast();
  final StreamController<StepSegment> _hourlySegmentController = StreamController<StepSegment>.broadcast();
  final StreamController<TacticalPulse> _tacticalPulseController = StreamController<TacticalPulse>.broadcast();

  int _lastKnownStepCount = 0;
  int _todayCumulativeSteps = 0;
  PlayerModel? _playerContext;
  final Map<int, int> _hourlyStepsBuffer = {};
  Timer? _hourlyAggregationTimer;
  Timer? _simulationTimer;
  StreamSubscription<StepCount>? _hardwareSubscription;
  DateTime _lastStepTime = DateTime.now().subtract(const Duration(minutes: 5));
  bool _isPaused = false;

  Stream<int> get stepStream => _stepStreamController.stream;
  Stream<StepSegment> get hourlySegmentStream => _hourlySegmentController.stream;
  Stream<TacticalPulse> get tacticalPulseStream => _tacticalPulseController.stream;

  int get todayCumulativeSteps => _todayCumulativeSteps;
  int get steps => _todayCumulativeSteps;
  bool get isPaused => _isPaused;

  void setPaused(bool paused) {
    _isPaused = paused;
    debugPrint("[PEDOMETER] Tracking ${paused ? 'PAUSED (Anti-Cheat)' : 'RESUMED'}");
  }

  GhostStatus calculateGhostStatus(Map<String, int> baseline) {
    final now = DateTime.now();
    final currentHour = now.hour;
    final minutesIntoHour = now.minute;

    int ghostTarget = 0;
    for (int i = 0; i < currentHour; i++) {
      final hourKey = i.toString().padLeft(2, '0');
      ghostTarget += baseline[hourKey] ?? 0;
    }

    final currentHourKey = currentHour.toString().padLeft(2, '0');
    final stepsInCurrentHour = baseline[currentHourKey] ?? 0;
    ghostTarget += (stepsInCurrentHour * (minutesIntoHour / 60.0)).round();

    final int delta = _todayCumulativeSteps - ghostTarget;
    final double velocityIndex = ghostTarget > 0 ? _todayCumulativeSteps / ghostTarget : 1.0;

    return GhostStatus(
      stepsAhead: delta.abs(),
      isAhead: delta >= 0,
      ghostTarget: ghostTarget,
      velocityIndex: velocityIndex,
    );
  }

  Map<String, int> generateHistoricalBaseline(Map<String, dynamic> dailyHistory) {
    if (dailyHistory.isEmpty) return {};

    final Map<String, List<int>> hourlyAggregator = {};
    dailyHistory.forEach((date, data) {
      if (data is Map && data.containsKey('hourlySteps')) {
        final Map<String, dynamic> dayHourly = data['hourlySteps'];
        dayHourly.forEach((hour, steps) {
          hourlyAggregator.putIfAbsent(hour, () => []).add((steps as num).toInt());
        });
      }
    });

    final Map<String, int> averagedBaseline = {};
    hourlyAggregator.forEach((hour, stepsList) {
      if (stepsList.isNotEmpty) {
        averagedBaseline[hour] = (stepsList.reduce((a, b) => a + b) / stepsList.length).round();
      }
    });

    return averagedBaseline;
  }

  Stream<GhostStatus> getGhostStatusStream(Map<String, int> baseline) {
    return stepStream.map((_) => calculateGhostStatus(baseline));
  }

  void updatePlayerContext(PlayerModel? context) {
    if (context != null && _playerContext != null) {
      // If the cloud dailySteps was reset to 0, we must reset our local counter
      // to avoid carrying over yesterday's steps into the new day's UI and RPG calculations.
      if (context.dailySteps == 0 && _playerContext!.dailySteps > 0 && _todayCumulativeSteps > 0) {
        debugPrint("[PEDOMETER] Daily reset detected in player context. Resetting local steps.");
        _todayCumulativeSteps = 0;
        _stepStreamController.add(0);
        _lastKnownStepCount = 0; // Force re-anchor if hardware binding is used
      }
      
      // If the cloud steps caught up and surpassed our local count (e.g. sync from another device),
      // we should align with the cloud truth.
      if (context.dailySteps > _todayCumulativeSteps) {
        _todayCumulativeSteps = context.dailySteps;
        _stepStreamController.add(_todayCumulativeSteps);
      }
    }
    _playerContext = context;
  }

  void startTracking({bool useSimulator = false, bool shouldBindHardware = false, PlayerModel? playerContext, int initialSteps = 0}) {
    _playerContext = playerContext;
    _todayCumulativeSteps = initialSteps;
    _hourlyStepsBuffer.clear();
    _startHourlyAggregationCycle();

    if (useSimulator) {
      _startStepSimulator(playerContext);
    } else if (shouldBindHardware) {
      _bindHardwareSensors();
    }
  }

  void dispose() {
    _hourlyAggregationTimer?.cancel();
    _simulationTimer?.cancel();
    _hardwareSubscription?.cancel();
    _stepStreamController.close();
    _hourlySegmentController.close();
    _tacticalPulseController.close();
  }

  void _bindHardwareSensors() {
    _hardwareSubscription?.cancel();
    _hardwareSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        _processRawHardwareSteps(event.steps);
      },
      onError: (error) => debugPrint("[TELEMETRY] PEDOMETER FAULT: $error"),
    );
  }

  void _processRawHardwareSteps(int totalHardwareSteps) {
    if (_lastKnownStepCount == 0) {
      _lastKnownStepCount = totalHardwareSteps;
      return;
    }

    final int delta = totalHardwareSteps - _lastKnownStepCount;
    
    // Handle hardware reboot or sensor reset
    if (delta < 0) {
      debugPrint("[TELEMETRY] Sensor reset detected (Step count decreased). Re-anchoring baseline.");
      _lastKnownStepCount = totalHardwareSteps;
      return;
    }

    if (delta > 0) {
      registerSteps(delta, playerContext: _playerContext);
    }
    _lastKnownStepCount = totalHardwareSteps;
  }

  void _startHourlyAggregationCycle() {
    _hourlyAggregationTimer?.cancel();
    _hourlyAggregationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final now = DateTime.now();
      final currentHour = now.hour;

      if (_hourlyStepsBuffer.containsKey(currentHour)) {
        final int hourDelta = _hourlyStepsBuffer[currentHour] ?? 0;
        if (hourDelta > 0) {
          final segment = StepSegment(
            hour: currentHour,
            stepDelta: hourDelta,
            timestamp: now,
          );
          _hourlySegmentController.add(segment);
          _hourlyStepsBuffer[currentHour] = 0;
        }
      }
    });
  }

  void registerSteps(int stepsCount, {PlayerModel? playerContext}) {
    if (_isPaused) return;

    _todayCumulativeSteps += stepsCount;
    _lastStepTime = DateTime.now();
    _stepStreamController.add(_todayCumulativeSteps);

    if (playerContext != null) {
      _emitTacticalPulse(stepsCount, playerContext);
    }

    final currentHour = DateTime.now().hour;
    _hourlyStepsBuffer[currentHour] = (_hourlyStepsBuffer[currentHour] ?? 0) + stepsCount;
  }

  void _emitTacticalPulse(int steps, PlayerModel player) {
    double bioDamageMult = 1.0;
    if (player.activePowerUps.containsKey("energy_boost")) {
      DateTime expiry = player.activePowerUps["energy_boost"]!;
      if (expiry.isAfter(DateTime.now())) {
        bioDamageMult = player.energyBoostRaidMultiplier.toDouble();
      }
    }

    final Map<String, int> historicalBaseline = generateHistoricalBaseline(player.dailyHistory);
    final Map<String, int> baseline = compileGhostBaseline(
        historicalBaseline.isNotEmpty ? historicalBaseline : player.hourlySteps
    );

    final status = calculateGhostStatus(baseline);
    double velocityBonus = 1.0;

    if (player.isGhostStriderEnabled && status.isAhead) {
      velocityBonus = (status.velocityIndex).clamp(1.0, 1.5);
    }

    double gearRaidMult = player.getModifier('raid_dmg_mult', allGear);
    double damage = GameplayRules.calculateRaidDamage(
      steps: steps,
      effectiveStrength: player.effectiveStrength,
      energyBoostMult: bioDamageMult,
      gearMult: gearRaidMult,
      velocityBonus: velocityBonus,
    );

    double scan = GameplayRules.calculateScanProgress(
      steps, 
      player.effectiveAgility, 
      velocityBonus: velocityBonus
    );

    int apGained = GameplayRules.calculateStaminaRefill(steps, player.effectiveEndurance);

    String? found;
    double lootChance = 0.05;
    if (player.isGhostStriderEnabled && status.isAhead) {
      lootChance = 0.08;
    }

    if (Random().nextDouble() < lootChance) {
      final materials = ["Silicon", "Dark Energy", "Circuitry", "Plating"];
      if (player.isGhostStriderEnabled && status.isAhead && Random().nextDouble() < 0.2) {
        found = "Power Core";
      } else {
        found = materials[Random().nextInt(materials.length)];
      }
    }

    _tacticalPulseController.add(TacticalPulse(
      steps: steps,
      raidDamage: damage,
      scanProgress: scan,
      apRegained: apGained,
      discoveredMaterial: found,
      velocityMultiplier: velocityBonus,
      isAheadOfGhost: status.isAhead,
    ));
  }

  Map<String, int> compileGhostBaseline(Map<String, int> rawHourlySteps) {
    final Map<String, int> normalDistributionCurve = {};
    for (int i = 0; i < 24; i++) {
      final String hourKey = i.toString().padLeft(2, '0');
      normalDistributionCurve[hourKey] = rawHourlySteps[hourKey] ?? _generateSimulatedGhostHour(i);
    }
    return normalDistributionCurve;
  }

  int _generateSimulatedGhostHour(int hour) {
    if (hour >= 23 || hour <= 5) return 20 + Random().nextInt(50);
    if (hour >= 8 && hour <= 10) return 600 + Random().nextInt(400);
    if (hour >= 12 && hour <= 13) return 400 + Random().nextInt(300);
    if (hour >= 17 && hour <= 19) return 800 + Random().nextInt(500);
    return 150 + Random().nextInt(200);
  }

  void _startStepSimulator(PlayerModel? playerContext) {
    _simulationTimer?.cancel();
    final random = Random();

    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isPaused) return;
      final int simulatedStrideDelta = 3 + random.nextInt(4);
      registerSteps(simulatedStrideDelta, playerContext: _playerContext);
    });
  }

  String getFitnessLevel(int totalDailySteps) {
    if (totalDailySteps < 2000) return "Sedentary Node";
    if (totalDailySteps < 5000) return "Active Sentinel";
    if (totalDailySteps < 8000) return "Command Pioneer";
    if (totalDailySteps < 12000) return "Ghost Strider Elite";
    return "Quantum Pathfinder";
  }

  void startListening() => startTracking(useSimulator: false, shouldBindHardware: true);
  void stopListening() => dispose();

  double calculateCalories() => _todayCumulativeSteps * GameplayRules.caloriesPerStep;
  double calculateDistanceKm() => _todayCumulativeSteps * GameplayRules.distanceKmPerStep;
  int getLevel() => (_todayCumulativeSteps / 2000).floor() + 1;
  bool isRealWalking() => DateTime.now().difference(_lastStepTime).inSeconds < 15;

  double getGoalProgress({int dailyGoal = 10000}) {
    if (dailyGoal <= 0) return 0.0;
    return _todayCumulativeSteps / dailyGoal;
  }

  void reset() {
    _todayCumulativeSteps = 0;
    _lastKnownStepCount = 0;
    _hourlyStepsBuffer.clear();
    _lastStepTime = DateTime.now().subtract(const Duration(minutes: 5));
    _isPaused = false;
    _playerContext = null;
    debugPrint("[PEDOMETER] PedometerService reset.");
  }
}