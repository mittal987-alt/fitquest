import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType { capture, teamRank, achievement, steps }

class ActivityFeedModel {
  final String id;
  final String playerName;
  final ActivityType type;
  final String message;
  final DateTime timestamp;

  ActivityFeedModel({
    required this.id,
    required this.playerName,
    required this.type,
    required this.message,
    required this.timestamp,
  });

  factory ActivityFeedModel.fromMap(Map<String, dynamic> map, String id) {
    return ActivityFeedModel(
      id: id,
      playerName: map['playerName'] ?? 'Unknown',
      type: ActivityType.values.firstWhere(
        (e) => e.toString() == 'ActivityType.${map['type']}',
        orElse: () => ActivityType.steps,
      ),
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'playerName': playerName,
      'type': type.toString().split('.').last,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
