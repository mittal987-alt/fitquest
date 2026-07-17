import 'package:cloud_firestore/cloud_firestore.dart';

class WalkSessionModel {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime endTime;
  final int steps;
  final double distanceKm;
  final List<WalkMemory> memories;

  WalkSessionModel({
    required this.id,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.steps,
    required this.distanceKm,
    this.memories = const [],
  });

  factory WalkSessionModel.fromMap(Map<String, dynamic> map, String id) {
    return WalkSessionModel(
      id: id,
      userId: map['userId'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      steps: map['steps'] ?? 0,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      memories: (map['memories'] as List? ?? [])
          .map((m) => WalkMemory.fromMap(m))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'steps': steps,
      'distanceKm': distanceKm,
      'memories': memories.map((m) => m.toMap()).toList(),
    };
  }
}

class WalkMemory {
  final String imageUrl;
  final String caption;
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  WalkMemory({
    required this.imageUrl,
    required this.caption,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  factory WalkMemory.fromMap(Map<String, dynamic> map) {
    return WalkMemory(
      imageUrl: map['imageUrl'] ?? '',
      caption: map['caption'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'caption': caption,
      'timestamp': Timestamp.fromDate(timestamp),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
