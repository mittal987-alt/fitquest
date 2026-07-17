import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationService {

  StreamSubscription<Position>?
  positionStream;

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
  // SPEED
  // =========================

  double getSpeedKmh(
      Position position) {

    return position.speed * 3.6;
  }

  // =========================
  // WALKING CHECK
  // =========================

  bool isWalking(double speed) {

    return speed > 1 &&
        speed <= 12;
  }

  // =========================
  // VEHICLE CHECK
  // =========================

  bool isVehicle(double speed) {

    return speed > 12;
  }

  // =========================
  // MOVEMENT STATUS
  // =========================

  String getMovementStatus(
      double speed) {

    if (speed <= 1) {
      return "🧍 Standing";
    }

    if (speed > 1 &&
        speed < 10) {

      return "🚶 Walking";
    }

    return "🚗 Vehicle";
  }
}