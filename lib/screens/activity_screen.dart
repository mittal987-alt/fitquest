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
  
  // Timer state
  Timer? _timer;
  int _seconds = 0;
  bool _isActive = true;

  // Telemetry state
  int _steps = 0;
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
  static const Color _kSecondaryPurple = Color(0xFF4A00E0);
  static const Color _kBgColor = Color(0xFF0D1117);
  static const Color _kSurfaceColor = Color(0xFF161B22);

  @override
  void initState() {
    super.initState();
    _startTimer();
    _initLocation();
    // Simulated initial data increment
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isActive) {
        setState(() {
          _steps += 5 + (timer.tick % 3);
          _distanceKm += 0.005;
          _calories += 0.3;
          _speedKmh = 5.0 + (timer.tick % 2 == 0 ? 0.2 : -0.2);
          _areaCapturedKm2 += 0.0001;
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

  Future<void> _initLocation() async {
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(pos.latitude, pos.longitude);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
                        if (widget.player != null) ...[
                          _buildHeatmapCard(widget.player!),
                          const SizedBox(height: 24),
                        ],
                        _buildSecondaryStatsGrid(),
                        const SizedBox(height: 40),
                        _buildActionButtons(),
                        const SizedBox(height: 100), // Space for mini map
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildMiniMap(),
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
            fontSize: 64,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            fontFamily: 'monospace',
          ),
        ),
        const Text(
          "ELAPSED MISSION TIME",
          style: TextStyle(color: _kPrimaryPurple, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _buildMainStats() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      decoration: BoxDecoration(
        color: _kSurfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: _kPrimaryPurple.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.directions_walk_rounded, color: _kPrimaryPurple, size: 32),
          const SizedBox(height: 12),
          Text(
            "👣 $_steps",
            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900),
          ),
          const Text(
            "TOTAL STEPS CAPTURED",
            style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
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
      childAspectRatio: 1.5,
      children: [
        _secondaryStatTile("📏 DISTANCE", "${_distanceKm.toStringAsFixed(1)} KM", Colors.blueAccent),
        _secondaryStatTile("🔥 CALORIES", "${_calories.toInt()} KCAL", Colors.orangeAccent),
        _secondaryStatTile("🚶 SPEED", "${_speedKmh.toStringAsFixed(1)} KM/H", Colors.cyanAccent),
        _secondaryStatTile("🟩 CAPTURED", "${_areaCapturedKm2.toStringAsFixed(3)} KM²", Colors.greenAccent),
      ],
    );
  }

  Widget _secondaryStatTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
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
                "FINISH WALK",
                Icons.stop_rounded,
                Colors.redAccent.withValues(alpha: 0.1),
                _finishWalk,
                textColor: Colors.redAccent,
                borderColor: Colors.redAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      // In a real app, you'd upload this to Firebase Storage first
      // For now, we'll just track it locally for the summary
      final pos = await Geolocator.getCurrentPosition();
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

  Widget _buildMiniMap() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 180,
        width: double.infinity,
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _kSurfaceColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: _kPrimaryPurple.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 15),
                onMapCreated: (c) => _mapController = c,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                polygons: _hexPolygons,
                style: _mapStyle, // Use a dark map style string
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.gps_fixed_rounded, color: _kPrimaryPurple, size: 14),
                    SizedBox(width: 8),
                    Text("LIVE TELEMETRY FEED", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
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

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WalkSummaryScreen(session: session),
      ),
    );
  }

  static const String _mapStyle = "[{\"featureType\":\"all\",\"elementType\":\"labels.text.fill\",\"stylers\":[{\"color\":\"#ffffff\"},{\"weight\":\"0.20\"},{\"lightness\":\"28\"},{\"visibility\":\"on\"},{\"brightness\":\"-27\"}]},{\"featureType\":\"all\",\"elementType\":\"labels.text.stroke\",\"stylers\":[{\"visibility\":\"on\"},{\"color\":\"#212121\"},{\"lightness\":16}]},{\"featureType\":\"all\",\"elementType\":\"labels.icon\",\"stylers\":[{\"visibility\":\"off\"}]},{\"featureType\":\"administrative\",\"elementType\":\"geometry.fill\",\"stylers\":[{\"color\":\"#212121\"},{\"lightness\":20}]},{\"featureType\":\"administrative\",\"elementType\":\"geometry.stroke\",\"stylers\":[{\"color\":\"#212121\"},{\"lightness\":17},{\"weight\":1.2}]},{\"featureType\":\"landscape\",\"elementType\":\"geometry\",\"stylers\":[{\"color\":\"#212121\"},{\"lightness\":20}]},{\"featureType\":\"poi\",\"elementType\":\"geometry\",\"stylers\":[{\"color\":\"#212121\"},{\"lightness\":21}]},{\"featureType\":\"road.highway\",\"elementType\":\"geometry.fill\",\"stylers\":[{\"color\":\"#212121\"},{\"lightness\":17}]},{\"featureType\":\"road.highway\",\"elementType\":\"geometry.stroke\",\"stylers\":[{\"color\":\"#212121\"},{\"lightness\":29},{\"weight\":0.2}]},{\"featureType\":\"road.arterial\",\"elementType\":\"geometry\",\"stylers\":[{\"color\":\"#212121\"},{\"lightness\":18}]},{\"featureType\":\"road.local\",\"elementType\":\"geometry\",\"stylers\":[{\"color\":\"#212121\"},{\"lightness\":16}]},{\"featureType\":\"transit\",\"elementType\":\"geometry\",\"stylers\":[{\"color\":\"#212121\"},{\"lightness\":19}]},{\"featureType\":\"water\",\"elementType\":\"geometry\",\"stylers\":[{\"color\":\"#000000\"},{\"lightness\":17}]}]";
}
