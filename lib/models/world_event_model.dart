import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorldEventModel {
  final String id;
  final String title;
  final String description;
  final LatLng position;
  final String eventType; // e.g., "Mineral Super-Node", "Data Breach"
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;
  final Map<String, int> teamContributions; // teamId -> contribution (e.g., damage or steps)
  final String? winningTeamId;
  final Map<String, int> rewards;

  WorldEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.position,
    required this.eventType,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    this.teamContributions = const {},
    this.winningTeamId,
    this.rewards = const {},
  });

  factory WorldEventModel.fromMap(Map<String, dynamic> map, String id) {
    return WorldEventModel(
      id: id,
      title: map['title'] ?? 'World Event',
      description: map['description'] ?? '',
      position: LatLng(map['latitude'] ?? 0.0, map['longitude'] ?? 0.0),
      eventType: map['eventType'] ?? 'super_node',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
      teamContributions: Map<String, int>.from(map['teamContributions'] ?? {}),
      winningTeamId: map['winningTeamId'],
      rewards: Map<String, int>.from(map['rewards'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'eventType': eventType,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isActive': isActive,
      'teamContributions': teamContributions,
      'winningTeamId': winningTeamId,
      'rewards': rewards,
    };
  }

  double get progress {
    if (!isActive) return 1.0;
    final now = DateTime.now();
    final total = endTime.difference(startTime).inSeconds;
    final elapsed = now.difference(startTime).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}
