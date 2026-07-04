import 'package:google_maps_flutter/google_maps_flutter.dart';

class AnomalyModel {
  final String id;
  final LatLng position;
  final String type; // e.g., "Data Cache", "Energy Rift", "Signal Trace"
  final Map<String, int> rewards; // e.g., {"Silicon": 5, "XP": 100}

  AnomalyModel({
    required this.id,
    required this.position,
    required this.type,
    required this.rewards,
  });

  factory AnomalyModel.fromMap(Map<String, dynamic> map, String id) {
    return AnomalyModel(
      id: id,
      position: LatLng(map['latitude'] ?? 0.0, map['longitude'] ?? 0.0),
      type: map['type'] ?? 'Unknown Anomaly',
      rewards: Map<String, int>.from(map['rewards'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'type': type,
      'rewards': rewards,
    };
  }
}
