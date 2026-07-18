import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'walk_summary_screen.dart';
import '../models/walk_session_model.dart';
import '../models/player_model.dart';
import '../services/firebase_service.dart';
import '../services/pedometer_service.dart';
import '../features/tactical/widgets/activity_heatmap.dart';

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
  
  // Timer state
  Timer? _timer;
  int _seconds = 0;
  bool _isActive = false;
  bool _hasStarted = false;

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
  final Set<Polygon> _hexPolygons = {};

  static const Color _kPrimaryPurple = Color(0xFF8E2DE2);
  static const Color _kBgColor = Color(0xFF0D1117);
  static const Color _kSurfaceColor = Color(0xFF161B22);

  @override
  void initState() {
    super.initState();
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
      if (_isActive) {
        setState(() {
          _seconds++;
        });
      }
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

  @override
  void dispose() {
    _timer?.cancel();
    _pedometerSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildTimerDisplay(),
                        const SizedBox(height: 32),
                        _buildMainStats(),
                        const SizedBox(height: 24),
                        _buildSecondaryStatsGrid(),
                        if (widget.player != null && widget.player!.isGhostStriderEnabled) ...[
                          const SizedBox(height: 24),
                          _buildHeatmapCard(widget.player!),
                        ],
                        const SizedBox(height: 40),
                        _buildActionButtons(),
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

  Widget _buildHeatmapCard(PlayerModel player) {
    final pedometerService = PedometerService();
    final Map<String, int> historicalBaseline = pedometerService.generateHistoricalBaseline(player.dailyHistory);
    // Use historical baseline if available, fallback to hardcoded map or service defaults
    final Map<String, int> baseline = (historicalBaseline.isNotEmpty) ? historicalBaseline : player.hourlySteps;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ACTIVITY INTENSITY",
            style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          ),
          const Text(
            "SESSION IN PROGRESS",
            style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2),
          ),
          const SizedBox(width: 48), // Spacer
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    return Column(
      children: [
        Text(
          _formatTime(_seconds),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 90,
            fontWeight: FontWeight.w900,
            letterSpacing: -4,
          ),
        ),
        const Text(
          "ELAPSED MISSION TIME",
          style: TextStyle(color: _kPrimaryPurple, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _buildMainStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: _kSurfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          const Icon(Icons.directions_run_rounded, color: _kPrimaryPurple, size: 36),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("👣", style: TextStyle(fontSize: 54)),
              const SizedBox(width: 16),
              Text(
                "$_steps",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 78,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "TOTAL STEPS CAPTURED",
            style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _secondaryStatTile("DISTANCE", "${_distanceKm.toStringAsFixed(1)} KM", Colors.white, "📏"),
        _secondaryStatTile("CALORIES", "${_calories.toInt()} KCAL", Colors.white, "🔥"),
        _secondaryStatTile("SPEED", "${_speedKmh.toStringAsFixed(1)} KM/H", Colors.white, "🚶"),
        _secondaryStatTile("CAPTURED", "${_areaCapturedKm2.toStringAsFixed(3)} KM²", Colors.white, "🟩"),
      ],
    );
  }

  Widget _secondaryStatTile(String label, String value, Color color, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _kSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (!_hasStarted) {
      return _actionButton(
        "START MISSION",
        Icons.play_arrow_rounded,
        _kPrimaryPurple,
        _startMission,
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionButton(
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
                      "PAUSE",
                      Icons.pause_rounded,
                      Colors.white10,
                      () => setState(() => _isActive = false),
                    )
                  : _actionButton(
                      "RESUME",
                      Icons.play_arrow_rounded,
                      _kPrimaryPurple,
                      () => setState(() => _isActive = true),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionButton(
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

  void _startMission() {
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
  }

  void _resetSession() {
    setState(() {
      _steps = 0;
      _initialSteps = _pedometerService.todayCumulativeSteps;
      _seconds = 0;
      _distanceKm = 0.0;
      _calories = 0.0;
      _memories.clear();
      _areaCapturedKm2 = 0.0;
      _speedKmh = 0.0;
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

  Widget _actionButton(String label, IconData icon, Color bgColor, VoidCallback onTap, {Color textColor = Colors.white, Color? borderColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.1), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }


  void _finishWalk() async {
    _timer?.cancel();
    
    final session = WalkSessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: _service.auth.currentUser?.uid ?? "",
      startTime: DateTime.now().subtract(Duration(seconds: _seconds)),
      endTime: DateTime.now(),
      steps: _steps,
      distanceKm: _distanceKm,
      memories: _memories,
    );

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      await _service.saveWalkSession(session);
      if (mounted) {
        Navigator.pop(context); // Close loading
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save session: $e"), backgroundColor: Colors.red),
        );
      }
    }

    if (!mounted) return;

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
}
