
enum MissionType { steps, distance, capture, xp, workout }

class MissionModel {
  final String id;
  final String title;
  final String description;
  final MissionType type;
  final double target;
  final int rewardXp;
  final int rewardCoins;
  final bool isWeekly;

  MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.rewardXp,
    required this.rewardCoins,
    this.isWeekly = false,
  });

  factory MissionModel.fromMap(Map<String, dynamic> map, String id) {
    return MissionModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: MissionType.values.firstWhere((e) => e.toString() == 'MissionType.${map['type']}', orElse: () => MissionType.steps),
      target: (map['target'] as num?)?.toDouble() ?? 0.0,
      rewardXp: (map['rewardXp'] as num?)?.toInt() ?? 0,
      rewardCoins: (map['rewardCoins'] as num?)?.toInt() ?? 0,
      isWeekly: map['isWeekly'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'target': target,
      'rewardXp': rewardXp,
      'rewardCoins': rewardCoins,
      'isWeekly': isWeekly,
    };
  }
}
