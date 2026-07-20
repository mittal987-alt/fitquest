import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_feed_model.dart' as fit;
import 'walk_summary_screen.dart';
import '../models/walk_session_model.dart';
import '../models/player_model.dart';
import '../models/activity_model.dart';
import '../services/firebase_service.dart';
import '../services/pedometer_service.dart';
import '../features/tactical/widgets/activity_heatmap.dart';

enum ActivityMode { walk, training }

class ActivityScreen extends StatefulWidget {
  final PlayerModel? player;
  const ActivityScreen({super.key, this.player});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final FirebaseService _service = FirebaseService();
  final PedometerService _pedometerService = PedometerService();
  StreamSubscription<int>? _pedometerSubscription;
  StreamSubscription<Position>? _positionSubscription;
  
  ActivityMode _selectedMode = ActivityMode.walk;
  ActivityModel? _trainingModel;
  final PageController _exercisePageController = PageController();
  int _currentExerciseIndex = 0;

  // Timer state
  Timer? _timer;
  int _seconds = 0;
  bool _isActive = false;
  bool _hasStarted = false;

  // Rest Timer state
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isResting = false;

  // Telemetry state
  int _steps = 0;
  int _initialSteps = 0;
  double _distanceKm = 0.0;
  double _calories = 0.0;
  double _speedKmh = 0.0;
  double _areaCapturedKm2 = 0.0;
  final List<WalkMemory> _memories = [];
  final ImagePicker _picker = ImagePicker();

  // Map state
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(0, 0);

  static const Color _kPrimaryPurple = Colors.blueAccent;

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    _pedometerSubscription?.cancel();
    _positionSubscription?.cancel();
    _exercisePageController.dispose();
    super.dispose();
  }

  void _loadTrainingModel() {
    if (widget.player != null) {
      double? bmi;
      if (widget.player!.heightCm != null && widget.player!.weightKg != null && widget.player!.heightCm! > 0) {
        double meters = widget.player!.heightCm! / 100;
        bmi = widget.player!.weightKg! / (meters * meters);
      }
      _trainingModel = ActivityModel.fromBmiAndGoal(
        bmi,
        widget.player!.fitnessGoal,
        trustScore: widget.player!.trustScore,
        level: widget.player!.level,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTrainingModel();
    _initLocation();
    _initPedometer();
  }

  void _initPedometer() {
    _initialSteps = _pedometerService.todayCumulativeSteps;
    _pedometerSubscription = _pedometerService.stepStream.listen((totalSteps) {
      if (_isActive) {
        setState(() {
          _steps = totalSteps - _initialSteps;
          // Calibrated multipliers to match your 'proper' telemetry session
          _distanceKm = _steps * 0.00081; 
          _calories = _steps * 0.043;
          
          if (_seconds > 0) {
             // Calculate speed and cap for UI realism during high-frequency simulation
             double rawSpeed = (_distanceKm / (_seconds / 3600));
             _speedKmh = rawSpeed.clamp(0.0, 12.0); 
          }
          
          _areaCapturedKm2 = _steps * 0.0000012; 
        });
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isActive && !_isResting) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  void _startRestTimer(int duration) {
    _restTimer?.cancel();
    setState(() {
      _isResting = true;
      _restSecondsRemaining = duration;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining > 0) {
        setState(() {
          _restSecondsRemaining--;
        });
      } else {
        _stopRestTimer();
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restSecondsRemaining = 0;
    });
  }

  void _initLocation() async {
    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_currentPosition),
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentPosition),
        );
      }
    });
  }

  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(colorScheme),
                if (!_hasStarted) _buildModeSelector(theme),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildTimerDisplay(theme),
                        const SizedBox(height: 32),
                        if (_selectedMode == ActivityMode.walk) ...[
                          _buildMainStats(theme),
                          const SizedBox(height: 24),
                          _buildSecondaryStatsGrid(theme),
                        ] else ...[
                          _buildTrainingGuide(theme),
                        ],
                        if (widget.player != null && widget.player!.isGhostStriderEnabled && _selectedMode == ActivityMode.walk) ...[
                          const SizedBox(height: 24),
                          _buildHeatmapCard(theme, widget.player!),
                        ],
                        const SizedBox(height: 40),
                        _buildActionButtons(theme),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Expanded(child: _modeButton(theme, "WALK", ActivityMode.walk)),
            Expanded(child: _modeButton(theme, "TRAINING", ActivityMode.training)),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(ThemeData theme, String label, ActivityMode mode) {
    final bool isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildTrainingGuide(ThemeData theme) {
    if (_trainingModel == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(Icons.fitness_center_rounded, color: theme.colorScheme.primary, size: 36),
              const SizedBox(height: 16),
              Text(
                "TIER: ${_trainingModel!.tier}",
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                "TARGET: ${_trainingModel!.durationMinutes} MINUTES",
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "EXERCISE ${_currentExerciseIndex + 1}/${_trainingModel!.exerciseGuide.length}",
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2),
            ),
            if (_isActive && !_isResting)
              GestureDetector(
                onTap: () => _startRestTimer(_trainingModel!.restIntervalSeconds),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.orangeAccent, size: 14),
                      SizedBox(width: 4),
                      Text("REST", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _exercisePageController,
            onPageChanged: (index) => setState(() => _currentExerciseIndex = index),
            itemCount: _trainingModel!.exerciseGuide.length,
            itemBuilder: (context, index) {
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _currentExerciseIndex == index ? 1.0 : 0.5,
                child: _buildExerciseTile(theme, _trainingModel!.exerciseGuide[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _currentExerciseIndex > 0 
                ? () => _exercisePageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                : null,
              icon: Icon(Icons.arrow_back_ios_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () {
                if (_currentExerciseIndex < _trainingModel!.exerciseGuide.length - 1) {
                  _startRestTimer(_trainingModel!.restIntervalSeconds);
                  _exercisePageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                _currentExerciseIndex < _trainingModel!.exerciseGuide.length - 1 ? "NEXT EXERCISE" : "FINAL SET",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 20),
            IconButton(
              onPressed: _currentExerciseIndex < _trainingModel!.exerciseGuide.length - 1
                ? () => _exercisePageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                : null,
              icon: Icon(Icons.arrow_forward_ios_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExerciseTile(ThemeData theme, Map<String, String> exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              exercise['target'] ?? "GO",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  exercise['name']?.toUpperCase() ?? "EXERCISE",
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Text(
                  exercise['tip'] ?? "",
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard(ThemeData theme, PlayerModel player) {
    final pedometerService = PedometerService();
    final Map<String, int> historicalBaseline = pedometerService.generateHistoricalBaseline(player.dailyHistory);
    // Use historical baseline if available, fallback to hardcoded map or service defaults
    final Map<String, int> baseline = (historicalBaseline.isNotEmpty) ? historicalBaseline : player.hourlySteps;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ACTIVITY INTENSITY",
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          ActivityHeatmap(
            hourlySteps: player.hourlySteps,
            ghostBaseline: pedometerService.compileGhostBaseline(baseline),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: colorScheme.onSurface, size: 28),
          ),
          Text(
            "SESSION IN PROGRESS",
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2),
          ),
          const SizedBox(width: 48), // Spacer
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(ThemeData theme) {
    return Column(
      children: [
        if (_isResting) ...[
          Text(
            "${(_restSecondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_restSecondsRemaining % 60).toString().padLeft(2, '0')}",
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 90,
              fontWeight: FontWeight.w900,
              letterSpacing: -4,
            ),
          ),
          const Text(
            "REST INTERVAL ACTIVE",
            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _stopRestTimer,
            child: Text("SKIP REST", style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.bold)),
          ),
        ] else ...[
          Text(
            _formatTime(_seconds),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 90,
              fontWeight: FontWeight.w900,
              letterSpacing: -4,
            ),
          ),
          Text(
            "ELAPSED MISSION TIME",
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2),
          ),
        ],
      ],
    );
  }

  Widget _buildMainStats(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.directions_run_rounded, color: theme.colorScheme.primary, size: 36),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("👣", style: TextStyle(fontSize: 54)),
              const SizedBox(width: 16),
              Text(
                "$_steps",
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 78,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "TOTAL STEPS CAPTURED",
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryStatsGrid(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _secondaryStatTile(theme, "DISTANCE", "${_distanceKm.toStringAsFixed(1)} KM", theme.colorScheme.onSurface, "📏"),
        _secondaryStatTile(theme, "CALORIES", "${_calories.toInt()} KCAL", theme.colorScheme.onSurface, "🔥"),
        _secondaryStatTile(theme, "SPEED", "${_speedKmh.toStringAsFixed(1)} KM/H", theme.colorScheme.onSurface, "🚶"),
        _secondaryStatTile(theme, "CAPTURED", "${_areaCapturedKm2.toStringAsFixed(3)} KM²", theme.colorScheme.onSurface, "🟩"),
      ],
    );
  }

  Widget _secondaryStatTile(ThemeData theme, String label, String value, Color color, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    if (!_hasStarted) {
      return _actionButton(
        theme,
        "START MISSION",
        Icons.play_arrow_rounded,
        theme.colorScheme.primary,
        _startMission,
        textColor: theme.colorScheme.onPrimary,
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionButton(
                theme,
                "SNAP MEMORY",
                Icons.camera_alt_rounded,
                Colors.cyanAccent.withValues(alpha: 0.1),
                _takePhoto,
                textColor: Colors.cyanAccent,
                borderColor: Colors.cyanAccent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionButton(
                theme,
                "RESET",
                Icons.refresh_rounded,
                Colors.orangeAccent.withValues(alpha: 0.1),
                _resetSession,
                textColor: Colors.orangeAccent,
                borderColor: Colors.orangeAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _isActive
                  ? _actionButton(
                      theme,
                      "PAUSE",
                      Icons.pause_rounded,
                      theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      () => setState(() => _isActive = false),
                      textColor: theme.colorScheme.onSurface,
                    )
                  : _actionButton(
                      theme,
                      "RESUME",
                      Icons.play_arrow_rounded,
                      theme.colorScheme.primary,
                      () => setState(() => _isActive = true),
                      textColor: theme.colorScheme.onPrimary,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionButton(
                theme,
                "SAVE & STOP",
                Icons.check_circle_rounded,
                Colors.greenAccent.withValues(alpha: 0.1),
                _finishWalk,
                textColor: Colors.greenAccent,
                borderColor: Colors.greenAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _startMission() async {
    setState(() {
      _hasStarted = true;
      _isActive = true;
      _initialSteps = _pedometerService.todayCumulativeSteps;
      _steps = 0;
      _seconds = 0;
      _distanceKm = 0.0;
      _calories = 0.0;
    });
    _startTimer();

    // Log to activity feed
    try {
      final activity = fit.ActivityFeedModel(
        id: "",
        userId: _service.auth.currentUser?.uid,
        teamId: widget.player?.teamId,
        playerName: widget.player?.name,
        type: _selectedMode == ActivityMode.walk 
            ? fit.ActivityType.walkSessionStarted 
            : fit.ActivityType.trainingSessionStarted,
        message: _selectedMode == ActivityMode.walk 
            ? "started a reconnaissance walk" 
            : "initiated a ${_trainingModel?.tier ?? 'ACTIVE'} training protocol",
        timestamp: DateTime.now(),
      );
      await _service.logActivity(activity);
    } catch (e) {
      debugPrint("Error logging mission start: $e");
    }
  }

  void _resetSession() {
    _restTimer?.cancel();
    setState(() {
      _steps = 0;
      _initialSteps = _pedometerService.todayCumulativeSteps;
      _seconds = 0;
      _distanceKm = 0.0;
      _calories = 0.0;
      _memories.clear();
      _areaCapturedKm2 = 0.0;
      _speedKmh = 0.0;
      _isResting = false;
      _restSecondsRemaining = 0;
    });
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      // In a real app, you'd upload this to Firebase Storage first
      // For now, we'll just track it locally for the summary
      final pos = await Geolocator.getCurrentPosition();
      
      if (!mounted) return;

      setState(() {
        _memories.add(WalkMemory(
          imageUrl: photo.path, // Local path for preview
          caption: "Captured at ${_formatTime(_seconds)}",
          timestamp: DateTime.now(),
          latitude: pos.latitude,
          longitude: pos.longitude,
        ));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("MEMORY CAPTURED!"), backgroundColor: Colors.cyan),
      );
    }
  }

  Widget _actionButton(ThemeData theme, String label, IconData icon, Color bgColor, VoidCallback onTap, {Color? textColor, Color? borderColor}) {
    final effectiveTextColor = textColor ?? theme.colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.1), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: effectiveTextColor, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: effectiveTextColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }


  void _finishWalk() async {
    _timer?.cancel();
    _restTimer?.cancel();
    
    // Final Telemetry Snapshot
    final int finalSteps = _steps;
    final double finalDistance = _distanceKm;
    final int finalSeconds = _seconds;
    final List<WalkMemory> finalMemories = List.from(_memories);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    if (_selectedMode == ActivityMode.walk) {
      final session = WalkSessionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _service.auth.currentUser?.uid ?? "",
        startTime: DateTime.now().subtract(Duration(seconds: finalSeconds)),
        endTime: DateTime.now(),
        steps: finalSteps,
        distanceKm: finalDistance,
        memories: finalMemories,
      );

      try {
        await _service.saveWalkSession(session);
        
        // Log mission completion to activity feed
        final activity = fit.ActivityFeedModel(
          id: "",
          userId: _service.auth.currentUser?.uid,
          teamId: widget.player?.teamId,
          playerName: widget.player?.name,
          type: fit.ActivityType.walkSessionEnded,
          message: "completed their mission with ${session.steps} steps!",
          timestamp: DateTime.now(),
        );
        await _service.logActivity(activity);

        if (mounted) {
          Navigator.pop(context); // Close loading
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WalkSummaryScreen(
                session: session,
                player: widget.player,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save session: $e"), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      // Training Session completion
      try {
        final double raidDamage = (finalSeconds / 60) * (_trainingModel?.raidDamageMultiplier ?? 1.0) * 10;
        final int xp = ((finalSeconds / 60) * (_trainingModel?.xpMultiplier ?? 1.0) * 50).toInt();
        bool bossDefeated = false;

        if (widget.player?.uid != null) {
          // Update player's local stats first
          await _service.firestore.collection("players").doc(widget.player!.uid).update({
            "xp": FieldValue.increment(xp),
            "totalRaidDamage": FieldValue.increment(raidDamage.toInt()),
          });
          
          if (widget.player?.teamId != null) {
            final result = await _service.contributeRaidDamage(widget.player!.teamId!, raidDamage);
            bossDefeated = result["defeated"] == true;
          }

          // Record training in history for the chart tooltip
          final todayKey = DateTime.now().toIso8601String().split('T')[0];
          await _service.firestore.collection("players").doc(widget.player!.uid).update({
            "dailyHistory.$todayKey.trainingSessions": FieldValue.arrayUnion([{
              "duration": finalSeconds,
              "xp": xp,
              "damage": raidDamage,
              "timestamp": DateTime.now().toIso8601String(),
            }]),
          });
        }

        // Log training completion to activity feed
        final activity = fit.ActivityFeedModel(
          id: "",
          userId: _service.auth.currentUser?.uid,
          teamId: widget.player?.teamId,
          playerName: widget.player?.name,
          type: fit.ActivityType.trainingSessionEnded,
          message: bossDefeated 
              ? "DEFEATED THE RAID BOSS during a ${_formatTime(finalSeconds)} training session!" 
              : "completed a ${_formatTime(finalSeconds)} training session and dealt ${raidDamage.toInt()} damage!",
          timestamp: DateTime.now(),
        );
        await _service.logActivity(activity);

        if (mounted) {
          Navigator.pop(context); // Close loading
          _showTrainingSummary(xp, raidDamage, finalSeconds);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save training: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showTrainingSummary(int xp, double damage, int finalSeconds) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.colorScheme.primary)),
        title: Text("TRAINING COMPLETE", style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow(theme, "DURATION", _formatTime(finalSeconds)),
            const SizedBox(height: 12),
            _summaryRow(theme, "XP EARNED", "+$xp"),
            const SizedBox(height: 12),
            _summaryRow(theme, "RAID DAMAGE", "${damage.toInt()} DMG"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text("DISMISS", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
