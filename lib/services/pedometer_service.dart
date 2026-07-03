import 'dart:async';
import 'dart:math';
import 'package:pedometer/pedometer.dart';
import '../models/player_model.dart';

/// Represents the RPG impact of physical movement segments.
class TacticalPulse {
  final double raidDamage;
  final double scanProgress;
  final int apRegained;
  final String? discoveredMaterial;

  TacticalPulse({
    required this.raidDamage,
    required this.scanProgress,
    required this.apRegained,
    this.discoveredMaterial,
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
  final Map<int, int> _hourlyTelemetryBuffer = {};
  Timer? _hourlyAggregationTimer;
  Timer? _simulationTimer;
  StreamSubscription<StepCount>? _hardwareSubscription;
  DateTime _lastStepTime = DateTime.now().subtract(const Duration(minutes: 5));

  // Public streams exposed to the application architecture
  Stream<int> get stepStream => _stepStreamController.stream;
  Stream<StepSegment> get hourlySegmentStream => _hourlySegmentController.stream;
  Stream<TacticalPulse> get tacticalPulseStream => _tacticalPulseController.stream;

  int get todayCumulativeSteps => _todayCumulativeSteps;
  int get steps => _todayCumulativeSteps;

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

  /// Provides a stream of GhostStatus updates given a fixed or dynamic baseline.
  Stream<GhostStatus> getGhostStatusStream(Map<String, int> baseline) {
    return stepStream.map((_) => calculateGhostStatus(baseline));
  }

  /// Bootstraps tracking streams. Connects to device sensors or initializes 
  /// simulation routines in emulator scenarios.
  void startTracking({bool useSimulator = true, PlayerModel? playerContext}) {
    _hourlyTelemetryBuffer.clear();
    _startHourlyAggregationCycle();

    if (useSimulator) {
      _startStepSimulator(playerContext);
    } else {
      _bindHardwareSensors(); // Note: Hardware sensors will need context passed differently in real use
    }
  }

  /// Closes internal active controllers and periodic background routines safely.
  void dispose() {
    _hourlyAggregationTimer?.cancel();
    _simulationTimer?.cancel();
    _hardwareSubscription?.cancel();
    _stepStreamController.close();
    _hourlySegmentController.close();
  }

  /// Binds to real hardware signals. (Typically integrates the standard 'pedometer' package stream)
  void _bindHardwareSensors() {
    _hardwareSubscription?.cancel();
    _hardwareSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        _processRawHardwareSteps(event.steps);
      },
      onError: (error) => print("[TELEMETRY] PEDOMETER FAULT: $error"),
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
      _registerSteps(delta);
    }
    _lastKnownStepCount = totalHardwareSteps;
  }

  /// Sets up a system loop to parse accumulated telemetry at hour boundaries.
  void _startHourlyAggregationCycle() {
    _hourlyAggregationTimer?.cancel();
    
    // Evaluate buffers periodically (simulation scales this down to 30-second sweeps, 
    // whereas live hardware updates trigger at real-time hour ticks)
    _hourlyAggregationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final now = DateTime.now();
      final currentHour = now.hour;

      if (_hourlyTelemetryBuffer.containsKey(currentHour)) {
        final int hourDelta = _hourlyTelemetryBuffer[currentHour] ?? 0;
        if (hourDelta > 0) {
          final segment = StepSegment(
            hour: currentHour,
            stepDelta: hourDelta,
            timestamp: now,
          );
          _hourlySegmentController.add(segment);
          // Flush localized tracking segment upon emission
          _hourlyTelemetryBuffer[currentHour] = 0;
        }
      }
    });
  }

  /// Safely records newly registered walking steps into live cumulative pools.
  void _registerSteps(int stepsCount, {PlayerModel? playerContext}) {
    _todayCumulativeSteps += stepsCount;
    _lastStepTime = DateTime.now();
    _stepStreamController.add(_todayCumulativeSteps);

    // Emit Tactical Pulse if player context is provided
    if (playerContext != null) {
      _emitTacticalPulse(stepsCount, playerContext);
    }

    final currentHour = DateTime.now().hour;
    _hourlyTelemetryBuffer[currentHour] = (_hourlyTelemetryBuffer[currentHour] ?? 0) + stepsCount;
  }

  void _emitTacticalPulse(int steps, PlayerModel player) {
    // RPG Logic: Strength increases Raid Damage
    double damage = steps * (player.effectiveStrength / 10.0);
    
    // RPG Logic: Agility increases Scanning Velocity
    double scan = steps * (player.effectiveAgility / 5000.0);

    // RPG Logic: Endurance increases AP recovery frequency
    int apGained = (steps / (200 - player.effectiveEndurance)).floor();

    // Loot Logic: 5% chance to find a material per pulse
    String? found;
    if (Random().nextDouble() < 0.05) {
      final materials = ["Silicon", "Dark Energy", "Circuitry", "Plating"];
      found = materials[Random().nextInt(materials.length)];
    }

    _tacticalPulseController.add(TacticalPulse(
      raidDamage: damage,
      scanProgress: scan,
      apRegained: apGained,
      discoveredMaterial: found,
    ));
  }

  /// Translates absolute, raw historical telemetry configurations to 24-hour baseline distributions.
  Map<String, int> compileGhostBaseline(Map<String, int> rawHourlyTelemetry) {
    final Map<String, int> normalDistributionCurve = {};
    
    // Fill up 24 hours of ghost profiles to avoid UI breaking curves
    for (int i = 0; i < 24; i++) {
      final String hourKey = i.toString().padLeft(2, '0');
      normalDistributionCurve[hourKey] = rawHourlyTelemetry[hourKey] ?? _generateSimulatedGhostHour(i);
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

    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      // Simulate physical stride intervals: 15 to 45 steps every tick
      final int simulatedStrideDelta = 15 + random.nextInt(30);
      _registerSteps(simulatedStrideDelta, playerContext: playerContext);
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

  double calculateCalories() => _todayCumulativeSteps * 0.04;
  double calculateDistanceKm() => _todayCumulativeSteps * 0.0008;
  int getLevel() => (_todayCumulativeSteps / 2000).floor() + 1;
  bool isRealWalking() => DateTime.now().difference(_lastStepTime).inSeconds < 15;
  
  double getGoalProgress({int dailyGoal = 10000}) {
    if (dailyGoal <= 0) return 0.0;
    return _todayCumulativeSteps / dailyGoal;
  }

  void reset() {
    _todayCumulativeSteps = 0;
    _lastKnownStepCount = 0;
    _hourlyTelemetryBuffer.clear();
  }
}
