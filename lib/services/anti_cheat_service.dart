import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../models/team_request_model.dart';

/// TRACKING ENGINE
/// Tracks geographical positions, monitors speed, and prevents cheating in real-time.
class MovementTrackingService {
  final FirebaseService _firebaseService = FirebaseService();
  final AntiCheatService _antiCheat = AntiCheatService();

  Position? _lastPosition;
  DateTime? _lastTimestamp;
  StreamSubscription<Position>? _positionStreamSub;

  // Track state flags locally
  String currentStatus = "🧍 STANDING";
  String operationalTrust = "TRUSTED";

  /// INITIALIZE BACKGROUND TRACKING
  void startTracking(String uid) {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Triggers stream update every 5 meters moved
    );

    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
        await _processMovementMetrics(uid, position);
      },
      onError: (error) {
        debugPrint("CRITICAL TRACKING ERROR: $error");
      },
    );
  }

  /// STOP BACKGROUND TRACKING
  void disposeTracking() {
    _positionStreamSub?.cancel();
  }

  /// CORE POSITION PROCESSOR AND ANTI-CHEAT FILTER
  Future<void> _processMovementMetrics(String uid, Position currentPosition) async {
    final DateTime now = DateTime.now();

    // 1. Calculate speeds and distances if a previous position cache exists
    if (_lastPosition != null && _lastTimestamp != null) {
      double distanceMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );

      double timeDeltaSeconds = now.difference(_lastTimestamp!).inSeconds.toDouble();

      // Teleport Jump Check (m/s & meters)
      if (_antiCheat.isTeleportJump(distanceMeters, timeDeltaSeconds)) {
        _antiCheat.applyTeleportPenalty();
        operationalTrust = _antiCheat.getTrustLevel();
        await _syncInfractionToCloud(uid);
        return;
      }
    }

    // 2. Convert standard Geolocator m/s unit to km/h for anti-cheat validation rules
    double speedKmH = currentPosition.speed * 3.6;
    currentStatus = _antiCheat.getMovementStatus(speedKmH);

    if (_antiCheat.isVehicle(speedKmH)) {
      _antiCheat.applyVehicleWarning();
      operationalTrust = _antiCheat.getTrustLevel();
      await _syncInfractionToCloud(uid);
    } else if (_antiCheat.isWalking(speedKmH)) {
      // If client was previously soft-blocked by vehicle speed, unlock them once they walk safely
      if (_antiCheat.isCaptureBlocked && speedKmH < 12.0) {
        _antiCheat.resetCaptureBlock();
      }
      // Note: Step counting is now handled by StepSyncService using hardware pedometer delta.
      // We no longer accrue steps based on GPS speed to avoid double-counting and inaccuracy.
    }

    // 3. Cache position data state for next tracking loop
    _lastPosition = currentPosition;
    _lastTimestamp = now;
  }

  /// SYNC INFRACTION STATUS TO DATABASE
  Future<void> _syncInfractionToCloud(String uid) async {
    await FirebaseFirestore.instance.collection("players").doc(uid).update({
      "trustScore": _antiCheat.trustScore,
      "warnings": _antiCheat.warnings,
      "xp": FieldValue.increment(-50), // Standard system penalty
    });
  }

  /// SEND JOIN REQUEST (RESTRICTED TO ONE ACTIVE REQUEST)
  Future<bool> dispatchTeamJoinRequest(BuildContext context, TeamRequestModel request) async {
    try {
      // Search the database for existing pending requests for this player
      final activeRequestsQuery = await FirebaseFirestore.instance
          .collection("requests")
          .where("playerId", isEqualTo: request.playerId)
          .where("status", isEqualTo: "pending")
          .get();

      // Enforce Rule: If any exist, deny request
      if (activeRequestsQuery.docs.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.orangeAccent,
              content: Text("REQUEST HALTED: CANCEL EXISTING PENDING REQUEST FIRST"),
            ),
          );
        }
        return false;
      }

      // No active blocks found; send join request
      await _firebaseService.sendJoinRequest(request);
      return true;
    } catch (e) {
      debugPrint("TEAM JOIN ERROR: $e");
      return false;
    }
  }
}

/// ANTI-CHEAT SECURITY ENGINE
class AntiCheatService {
  int warnings = 0;
  int trustScore = 100;
  int leaderboardPoints = 1000;
  bool captureBlocked = false;

  bool get isCaptureBlocked => captureBlocked;

  bool isVehicle(double speedKmH) => speedKmH > 15.0;
  bool isWalking(double speedKmH) => speedKmH >= 0.1 && speedKmH < 15.0;

  String getMovementStatus(double speedKmH) {
    if (speedKmH < 0.1) return "🧍 STANDING";
    if (speedKmH >= 0.1 && speedKmH < 15.0) return "🚶 WALKING";
    return "🚗 VEHICLE SPEED";
  }

  bool isTeleportJump(double distanceMeters, double timeSeconds) {
    if (timeSeconds <= 0) return false;
    double speedMS = distanceMeters / timeSeconds;
    return speedMS > 150.0 || distanceMeters > 1000.0;
  }

  void applyVehicleWarning() {
    warnings++;
    trustScore -= 10;
    captureBlocked = true;
    if (trustScore < 0) trustScore = 0;

    if (warnings >= 3) {
      leaderboardPoints -= 100;
      warnings = 0;
      if (leaderboardPoints < 0) leaderboardPoints = 0;
    }
  }

  void applyTeleportPenalty() {
    trustScore -= 20;
    captureBlocked = true;
    if (trustScore < 0) trustScore = 0;
  }

  void resetCaptureBlock() {
    captureBlocked = false;
  }

  String getTrustLevel() {
    if (trustScore >= 90) return "TRUSTED";
    if (trustScore >= 70) return "NORMAL";
    if (trustScore >= 40) return "SUSPICIOUS";
    return "FLAGGED";
  }

  bool canCapture({
    required bool userIsWalking,
    required bool captureBlocked,
    required double distanceToTileMeters,
    double distanceMultiplier = 1.0,
  }) {
    // Base radius (~222m) multiplied by augmentation factor
    double maxValidProximity = (0.002 * 2.0 * 111000) * distanceMultiplier;
    return userIsWalking && !captureBlocked && (distanceToTileMeters < maxValidProximity);
  }
}
