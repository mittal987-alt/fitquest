import 'package:cloud_firestore/cloud_firestore.dart';

class RelayModel {
  final String teamId;
  final String currentOperatorId;
  final String currentOperatorName;
  final int targetSteps;
  final int currentSteps;
  final bool isActive;
  final DateTime? startTime;
  final List<String> sequence; // List of UIDs in order

  RelayModel({
    required this.teamId,
    required this.currentOperatorId,
    required this.currentOperatorName,
    required this.targetSteps,
    required this.currentSteps,
    required this.isActive,
    this.startTime,
    this.sequence = const [],
  });

  factory RelayModel.fromMap(Map<String, dynamic> map) {
    return RelayModel(
      teamId: map['teamId'] ?? '',
      currentOperatorId: map['currentOperatorId'] ?? '',
      currentOperatorName: map['currentOperatorName'] ?? 'Unknown',
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
      'currentOperatorId': currentOperatorId,
      'currentOperatorName': currentOperatorName,
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
