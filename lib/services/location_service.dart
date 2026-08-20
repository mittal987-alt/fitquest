import 'dart:async';
import 'dart:collection';

import 'package:geolocator/geolocator.dart';

class LocationService {

  StreamSubscription<Position>?
  positionStream;

  // =========================
  // SPEED SMOOTHING STATE
  // =========================

  // Rolling buffer of recent *valid* speed readings (km/h), most recent last.
  final Queue<double> _recentSpeeds = Queue<double>();
  static const int _speedBufferSize = 5;

  // How many consecutive smoothed readings must classify as "vehicle"
  // before we actually treat the user as being in a vehicle.
  int _consecutiveVehicleReadings = 0;
  static const int _vehicleConfirmationThreshold = 3;

  // Discard any GPS fix whose reported speed accuracy is worse than this
  // (in m/s). A high speedAccuracy value means Geolocator itself isn't
  // confident in the speed figure, so treating it as truth causes false
  // vehicle-speed spikes, especially indoors or with a weak GPS lock.
  static const double _maxAcceptableSpeedAccuracy = 3.0;

  // Discard fixes with poor horizontal accuracy too — a jumpy position fix
  // produces a jumpy (fake) speed even if speedAccuracy looks fine.
  static const double _maxAcceptablePositionAccuracy = 25.0;

  // =========================
  // CHECK LOCATION
  // =========================

  Future<bool>
  checkPermission() async {

    bool serviceEnabled =
    await Geolocator
        .isLocationServiceEnabled();

    if (!serviceEnabled) {

      await Geolocator
          .openLocationSettings();

      return false;
    }

    LocationPermission permission =
    await Geolocator
        .checkPermission();

    if (permission ==
        LocationPermission.denied) {

      permission =
      await Geolocator
          .requestPermission();
    }

    if (permission ==
        LocationPermission.deniedForever) {

      return false;
    }

    return true;
  }

  // =========================
  // CURRENT LOCATION
  // =========================

  Future<Position>
  getCurrentLocation() async {

    return await Geolocator
        .getCurrentPosition(

      desiredAccuracy:
      LocationAccuracy.best,
    );
  }

  // =========================
  // LOCATION STREAM
  // =========================

  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    );
  }

  // =========================
  // DISTANCE
  // =========================

  double calculateDistance({

    required double startLat,

    required double startLng,

    required double endLat,

    required double endLng,
  }) {

    return Geolocator
        .distanceBetween(

      startLat,
      startLng,

      endLat,
      endLng,
    );
  }

  // =========================
  // SPEED (raw — kept for compatibility, avoid using directly for anti-cheat)
  // =========================

  double getSpeedKmh(
      Position position) {

    return position.speed * 3.6;
  }

  /// Returns true if this position fix is trustworthy enough to base
  /// speed/anti-cheat decisions on. Filters out the classic GPS noise
  /// sources: weak signal, low sample confidence, indoor multipath.
  bool _isReliableFix(Position position) {
    if (position.accuracy > _maxAcceptablePositionAccuracy) return false;

    // speedAccuracy may report 0 on some platforms/devices when unsupported —
    // treat that as "unknown" rather than "perfect", but don't hard-fail on it
    // alone since some Android devices always report 0.
    if (position.speedAccuracy > _maxAcceptableSpeedAccuracy) return false;

    return true;
  }

  /// Smoothed, debounced speed in km/h. Feeds only reliable fixes into a
  /// rolling window and returns their average, so a single noisy GPS
  /// reading can't cause a spike. Call this once per incoming Position
  /// instead of getSpeedKmh() for anything driving anti-cheat logic.
  double getSmoothedSpeedKmh(Position position) {
    if (!_isReliableFix(position)) {
      // Don't inject noisy data into the buffer, but don't reset it either —
      // just return the last known-good smoothed value (or 0 if none yet).
      return _recentSpeeds.isEmpty
          ? 0.0
          : _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
    }

    final rawKmh = position.speed * 3.6;

    _recentSpeeds.addLast(rawKmh);
    if (_recentSpeeds.length > _speedBufferSize) {
      _recentSpeeds.removeFirst();
    }

    return _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
  }

  // =========================
  // WALKING CHECK
  // =========================

  bool isWalking(double speed) {
    return speed >= 3.0 && speed <= 10.0;
  }

  // =========================
  // VEHICLE CHECK
  // =========================

  /// Raw, single-reading vehicle check. Kept for compatibility — prefer
  /// isVehicleConfirmed() for anything that pauses step tracking, since
  /// this alone is what caused false-positive step suppression.
  bool isVehicle(double speed) {
    return speed > 15.0;
  }

  /// Debounced vehicle check: only returns true once several consecutive
  /// smoothed readings have classified as vehicle-speed. This is what
  /// should actually gate pausing step collection — a single spike (GPS
  /// noise, a quick stairwell, a moment near a road) no longer suppresses
  /// real steps.
  bool isVehicleConfirmed(double smoothedSpeedKmh) {
    if (smoothedSpeedKmh > 15.0) {
      _consecutiveVehicleReadings++;
    } else {
      _consecutiveVehicleReadings = 0;
    }

    return _consecutiveVehicleReadings >= _vehicleConfirmationThreshold;
  }

  /// Call when tracking stops/resets so stale streaks don't leak into a
  /// new session.
  void resetSpeedTracking() {
    _recentSpeeds.clear();
    _consecutiveVehicleReadings = 0;
  }

  // =========================
  // MOVEMENT STATUS
  // =========================

  String getMovementStatus(double speed) {
    if (speed < 1.0) return "🧍 Standing";
    if (speed < 3.0) return "🐢 Strolling";
    if (speed <= 10.0) return "🚶 Walking";
    if (speed <= 15.0) return "🏃 Running";
    return "🚗 Vehicle";
  }
}