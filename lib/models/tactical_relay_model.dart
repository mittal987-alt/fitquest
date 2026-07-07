import 'package:cloud_firestore/cloud_firestore.dart';

class TacticalRelayModel {
  final String teamId;
  final String currentPlayerId;
  final String currentPlayerName;
  final int targetSteps;
  final int currentSteps;
  final bool isActive;
  final DateTime? startTime;
  final List<String> sequence; // List of UIDs in order

  TacticalRelayModel({
    required this.teamId,
    required this.currentPlayerId,
    required this.currentPlayerName,
    required this.targetSteps,
    required this.currentSteps,
    required this.isActive,
    this.startTime,
    this.sequence = const [],
  });

  factory TacticalRelayModel.fromMap(Map<String, dynamic> map) {
    return TacticalRelayModel(
      teamId: map['teamId'] ?? '',
      currentPlayerId: map['currentPlayerId'] ?? map['currentOperatorId'] ?? '',
      currentPlayerName: map['currentPlayerName'] ?? map['currentOperatorName'] ?? 'Unknown',
      targetSteps: map['targetSteps'] ?? 5000,
      currentSteps: map['currentSteps'] ?? 0,
      isActive: map['isActive'] ?? false,
      startTime: map['startTime'] is Timestamp ? (map['startTime'] as Timestamp).toDate() : null,
      sequence: List<String>.from(map['sequence'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'currentPlayerId': currentPlayerId,
      'currentPlayerName': currentPlayerName,
      'targetSteps': targetSteps,
      'currentSteps': currentSteps,
      'isActive': isActive,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'sequence': sequence,
    };
  }

  double get progress => (currentSteps / targetSteps).clamp(0.0, 1.0);
  int get remainingSteps => (targetSteps - currentSteps).clamp(0, targetSteps);
}
