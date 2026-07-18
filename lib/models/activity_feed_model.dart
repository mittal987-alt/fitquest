import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType { 
  capture, 
  teamRank, 
  achievement, 
  steps, 
  challengeStarted, 
  challengeCompleted, 
  rewardClaimed,
  teamChallengeReward,
  teamBuffActivated
}

class ActivityFeedModel {
  final String id;
  final String? userId;
  final String? teamId;
  final String? playerName;
  final ActivityType type;
  final String? itemId;
  final String message;
  final DateTime? timestamp;

  ActivityFeedModel({
    required this.id,
    this.userId,
    this.teamId,
    this.playerName,
    required this.type,
    this.itemId,
    required this.message,
    this.timestamp,
  });

  factory ActivityFeedModel.fromMap(Map<String, dynamic> map, String id) {
    return ActivityFeedModel(
      id: id,
      userId: map['userId'],
      teamId: map['teamId'],
      playerName: map['playerName'],
      type: _parseType(map['type']),
      itemId: map['itemId'],
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  static ActivityType _parseType(String? typeStr) {
    if (typeStr == null) return ActivityType.steps;
    return ActivityType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => ActivityType.steps,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (userId != null) 'userId': userId,
      if (teamId != null) 'teamId': teamId,
      if (playerName != null) 'playerName': playerName,
      'type': type.name,
      if (itemId != null) 'itemId': itemId,
      'message': message,
      if (timestamp != null) 'timestamp': Timestamp.fromDate(timestamp!),
    };
  }
}
