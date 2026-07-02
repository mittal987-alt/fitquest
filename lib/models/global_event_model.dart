import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalEventModel {
  final String id;
  final String title;
  final String description;
  final int targetSteps;
  final int currentSteps;
  final DateTime endDate;
  final String rewardType;
  final int rewardValue;
  final bool isActive;

  GlobalEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetSteps,
    required this.currentSteps,
    required this.endDate,
    required this.rewardType,
    required this.rewardValue,
    this.isActive = true,
  });

  factory GlobalEventModel.fromMap(Map<String, dynamic> map, String docId) {
    return GlobalEventModel(
      id: docId,
      title: map['title'] ?? 'OPERATION: UNKNOWN',
      description: map['description'] ?? 'NO DATA AVAILABLE',
      targetSteps: map['targetSteps'] ?? 1000000,
      currentSteps: map['currentSteps'] ?? 0,
      endDate: (map['endDate'] as Timestamp).toDate(),
      rewardType: map['rewardType'] ?? 'XP',
      rewardValue: map['rewardValue'] ?? 0,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'targetSteps': targetSteps,
      'currentSteps': currentSteps,
      'endDate': Timestamp.fromDate(endDate),
      'rewardType': rewardType,
      'rewardValue': rewardValue,
      'isActive': isActive,
    };
  }

  double get progress => (currentSteps / targetSteps).clamp(0.0, 1.0);
}
