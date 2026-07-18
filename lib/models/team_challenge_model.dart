import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeScope { daily, weekly }
enum ChallengeType { steps, distance, raidDamage, members }

class TeamChallengeModel {
  final String id;
  final String title;
  final String description;
  final ChallengeScope scope;
  final ChallengeType type;
  final double target;
  final double progress;
  final int xpReward;
  final int currencyReward;
  final DateTime expiresAt;
  final List<String> claimedMembers;

  TeamChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.scope,
    required this.type,
    required this.target,
    this.progress = 0,
    required this.xpReward,
    required this.currencyReward,
    required this.expiresAt,
    this.claimedMembers = const [],
  });

  factory TeamChallengeModel.fromMap(Map<String, dynamic> map, String id) {
    return TeamChallengeModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      scope: ChallengeScope.values.firstWhere((e) => e.name == (map['scope'] ?? 'daily')),
      type: ChallengeType.values.firstWhere((e) => e.name == (map['type'] ?? 'steps')),
      target: (map['target'] as num?)?.toDouble() ?? 0.0,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      xpReward: (map['xpReward'] as num?)?.toInt() ?? 0,
      currencyReward: (map['currencyReward'] as num?)?.toInt() ?? 0,
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      claimedMembers: map['claimedMembers'] != null ? List<String>.from(map['claimedMembers']) : const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'scope': scope.name,
      'type': type.name,
      'target': target,
      'progress': progress,
      'xpReward': xpReward,
      'currencyReward': currencyReward,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'claimedMembers': claimedMembers,
    };
  }

  bool get isCompleted => progress >= target;
  double get percentage => (progress / target).clamp(0.0, 1.0);
}
