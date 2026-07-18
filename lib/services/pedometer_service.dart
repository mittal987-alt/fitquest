import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import '../models/player_model.dart';
import '../config/gameplay_rules.dart';

/// Represents the RPG impact of physical movement segments.
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

/// Represents the live delta between the operator and their historical ghost baseline.
class GhostStatus {
  final int stepsAhead;
  final bool isAhead;
  final int ghostTarget;
  final double velocityIndex; // 1.0 = matching ghost, >1.0 = faster

  GhostStatus({
    required this.stepsAhead,
    required this.isAhead,
    required this.ghostTarget,
    required this.velocityIndex,
  });
}

/// Represents a chronological step segment capturing a specific hourly delta.
class StepSegment {
  final int hour; // 0 to 23 representing the hour of day
  final int stepDelta; // Steps walked within this specific hour segment
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

/// Service responsible for capturing physical step inputs, compiling chronological telemetry,
/// and streaming live updates to support the "Ghost Strider" relative velocity baselines.
class PedometerService {
  // Singleton instance pattern
  static final PedometerService _instance = PedometerService._internal();
  factory PedometerService() => _instance;
  PedometerService._internal();

  // Stream controllers to broadcast real-time data streams
  final StreamController<int> _stepStreamController = StreamController<int>.broadcast();
  final StreamController<StepSegment> _hourlySegmentController = StreamController<StepSegment>.broadcast();
  final StreamController<TacticalPulse> _tacticalPulseController = StreamController<TacticalPulse>.broadcast();

  // Internal state caches
  int _lastKnownStepCount = 0;
  int _todayCumulativeSteps = 0;
  PlayerModel? _playerContext;
  final Map<int, int> _hourlyStepsBuffer = {};
  Timer? _hourlyAggregationTimer;
  Timer? _simulationTimer;
  StreamSubscription<StepCount>? _hardwareSubscription;
  DateTime _lastStepTime = DateTime.now().subtract(const Duration(minutes: 5));
  bool _isPaused = false;

  // Public streams exposed to the application architecture
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

  /// Computes the live GhostStatus relative to a baseline.
  /// Interpolates the current hour's target steps based on minutes elapsed.
  GhostStatus calculateGhostStatus(Map<String, int> baseline) {
    final now = DateTime.now();
    final currentHour = now.hour;
    final minutesIntoHour = now.minute;

    int ghostTarget = 0;

    // Aggregate completed hours
    for (int i = 0; i < currentHour; i++) {
      final hourKey = i.toString().padLeft(2, '0');
      ghostTarget += baseline[hourKey] ?? 0;
    }

    // Interpolate current hour progress
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

  /// Aggregates historical daily archives into a single averaged hourly baseline.
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

  /// Provides a stream of GhostStatus updates given a fixed or dynamic baseline.
  Stream<GhostStatus> getGhostStatusStream(Map<String, int> baseline) {
    return stepStream.map((_) => calculateGhostStatus(baseline));
  }

  /// Updates the player profile context for RPG calculation and material discovery logic.
  void updatePlayerContext(PlayerModel? context) {
    _playerContext = context;
  }

  /// Bootstraps tracking streams. Connects to device sensors or initializes
  /// simulation routines in emulator scenarios.
  void startTracking({bool useSimulator = false, PlayerModel? playerContext, int initialSteps = 0}) {
    _playerContext = playerContext;
    _todayCumulativeSteps = initialSteps;
    _hourlyStepsBuffer.clear();
    _startHourlyAggregationCycle();

    if (useSimulator) {
      _startStepSimulator(playerContext);
    } else {
      _bindHardwareSensors();
    }
  }

  /// Closes internal active controllers and periodic background routines safely.
  void dispose() {
    _hourlyAggregationTimer?.cancel();
    _simulationTimer?.cancel();
    _hardwareSubscription?.cancel();
    _stepStreamController.close();
    _hourlySegmentController.close();
    // FIX: _tacticalPulseController was never closed here, unlike the other
    // two broadcast controllers — a straightforward resource-cleanup miss.
    _tacticalPulseController.close();
  }

  /// Binds to real hardware signals. (Typically integrates the standard 'pedometer' package stream)
  void _bindHardwareSensors() {
    _hardwareSubscription?.cancel();
    _hardwareSubscription = Pedometer.stepCountStream.listen(
          (StepCount event) {
        _processRawHardwareSteps(event.steps);
      },
      onError: (error) => debugPrint("[TELEMETRY] PEDOMETER FAULT: $error"),
    );
  }

  /// Processes absolute step counter readings to calculate relative step deltas.
  void _processRawHardwareSteps(int totalHardwareSteps) {
    if (_lastKnownStepCount == 0) {
      _lastKnownStepCount = totalHardwareSteps;
      return;
    }

    final int delta = totalHardwareSteps - _lastKnownStepCount;
    if (delta > 0) {
      registerSteps(delta, playerContext: _playerContext);
    }
    _lastKnownStepCount = totalHardwareSteps;
  }

  /// Sets up a system loop to parse accumulated steps at hour boundaries.
  void _startHourlyAggregationCycle() {
    _hourlyAggregationTimer?.cancel();

    // Evaluate buffers periodically (simulation scales this down to 30-second sweeps,
    // whereas live hardware updates trigger at real-time hour ticks)
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
          // Flush localized tracking segment upon emission
          _hourlyStepsBuffer[currentHour] = 0;
        }
      }
    });
  }

  /// Safely records newly registered walking steps into live cumulative pools.
  void registerSteps(int stepsCount, {PlayerModel? playerContext}) {
    if (_isPaused) return; // Anti-Cheat Block

    _todayCumulativeSteps += stepsCount;
    _lastStepTime = DateTime.now();
    _stepStreamController.add(_todayCumulativeSteps);

    // Emit Tactical Pulse if player context is provided
    if (playerContext != null) {
      _emitTacticalPulse(stepsCount, playerContext);
    }

    final currentHour = DateTime.now().hour;
    _hourlyStepsBuffer[currentHour] = (_hourlyStepsBuffer[currentHour] ?? 0) + stepsCount;
  }

  void _emitTacticalPulse(int steps, PlayerModel player) {
    // Determine Energy Boost Multiplier
    double bioDamageMult = 1.0;
    if (player.activePowerUps.containsKey("energy_boost")) {
      DateTime expiry = player.activePowerUps["energy_boost"]!;
      if (expiry.isAfter(DateTime.now())) {
        // Use the profile-calculated multiplier from PlayerModel
        bioDamageMult = player.energyBoostRaidMultiplier.toDouble();
      }
    }

    // Ghost Strider Velocity Bonus integration
    // Use historical baseline if available, fallback to hardcoded circadian curve
    final Map<String, int> historicalBaseline = generateHistoricalBaseline(player.dailyHistory);
    final Map<String, int> baseline = compileGhostBaseline(
        historicalBaseline.isNotEmpty ? historicalBaseline : player.hourlySteps
    );

    final status = calculateGhostStatus(baseline);
    double velocityBonus = 1.0;

    // Only apply bonus if the feature is explicitly enabled in player profile
    if (player.isGhostStriderEnabled && status.isAhead) {
      // Velocity Bonus scales up to 1.5x based on how much faster player is than ghost
      velocityBonus = (status.velocityIndex).clamp(1.0, 1.5);
    }

    // RPG Logic: Strength increases Raid Damage, modified by Energy Boost and Ghost Velocity
    double damage = (steps * (player.effectiveStrength / 10.0) * bioDamageMult * velocityBonus).toDouble();

    // RPG Logic: Agility increases Scanning Velocity, boosted by Ghost Strider velocity
    double scan = (steps * (player.effectiveAgility / 5000.0) * velocityBonus).toDouble();

    // RPG Logic: Endurance increases AP recovery frequency
    // BASE FORMULA: (steps / (200 - player.effectiveEndurance))
    // We cap effective endurance at 100 for this calculation to avoid division by zero or negative results
    double adjustedEndurance = player.effectiveEndurance.toDouble().clamp(0.0, 150.0);
    int apGained = (steps / (200 - adjustedEndurance)).floor();

    // Loot Logic: 5% chance to find a material per pulse,
    // increased to 8% if Ghost Strider is active and ahead.
    String? found;
    double lootChance = 0.05;
    if (player.isGhostStriderEnabled && status.isAhead) {
      lootChance = 0.08;
    }

    if (Random().nextDouble() < lootChance) {
      final materials = ["Silicon", "Dark Energy", "Circuitry", "Plating"];
      if (player.isGhostStriderEnabled && status.isAhead && Random().nextDouble() < 0.2) {
        found = "Power Core"; // 20% of successful loot is a Power Core if ahead of ghost
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

  /// Translates absolute, raw historical step configurations to 24-hour baseline distributions.
  Map<String, int> compileGhostBaseline(Map<String, int> rawHourlySteps) {
    final Map<String, int> normalDistributionCurve = {};

    // Fill up 24 hours of ghost profiles to avoid UI breaking curves
    for (int i = 0; i < 24; i++) {
      final String hourKey = i.toString().padLeft(2, '0');
      normalDistributionCurve[hourKey] = rawHourlySteps[hourKey] ?? _generateSimulatedGhostHour(i);
    }

    return normalDistributionCurve;
  }

  /// Fallback step distribution curves matching human circadian velocities.
  int _generateSimulatedGhostHour(int hour) {
    if (hour >= 23 || hour <= 5) return 20 + Random().nextInt(50); // Sleep levels
    if (hour >= 8 && hour <= 10) return 600 + Random().nextInt(400); // Commute rush
    if (hour >= 12 && hour <= 13) return 400 + Random().nextInt(300); // Lunch walks
    if (hour >= 17 && hour <= 19) return 800 + Random().nextInt(500); // Evening training
    return 150 + Random().nextInt(200); // Baseline active day hours
  }

  /// Simulates physical movement patterns dynamically when testing on desktop/simulators.
  void _startStepSimulator(PlayerModel? playerContext) {
    _simulationTimer?.cancel();
    final random = Random();

    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isPaused) return;
      // Walking speed: ~1.5 - 2.5 steps per second
      // Every 2 seconds: 3 to 6 steps is realistic.
      final int simulatedStrideDelta = 3 + random.nextInt(4);
      registerSteps(simulatedStrideDelta, playerContext: _playerContext);
    });
  }

  /// Evaluates relative active tiers using aggregate step metrics (corresponds with home dashboard metrics).
  String getFitnessLevel(int totalDailySteps) {
    if (totalDailySteps < 2000) return "Sedentary Node";
    if (totalDailySteps < 5000) return "Active Sentinel";
    if (totalDailySteps < 8000) return "Command Pioneer";
    if (totalDailySteps < 12000) return "Ghost Strider Elite";
    return "Quantum Pathfinder";
  }

  // ==========================================
  // COMPATIBILITY HELPERS (PREVIOUSLY PRESENT)
  // ==========================================

  void startListening() => startTracking(useSimulator: false);
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
  }
}