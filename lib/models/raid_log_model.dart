import 'package:cloud_firestore/cloud_firestore.dart';

class RaidLog {
  final String id;
  final String bossName;
  final DateTime timestamp;
  final double totalDamage;
  final String victorName;
  final List<String> lootDrops;
  final bool isSuccess;

  RaidLog({
    required this.id,
    required this.bossName,
    required this.timestamp,
    required this.totalDamage,
    required this.victorName,
    this.lootDrops = const [],
    this.isSuccess = true,
  });

  factory RaidLog.fromMap(Map<String, dynamic> map, String id) {
    return RaidLog(
      id: id,
      bossName: map['bossName'] ?? 'UNKNOWN_COLOSSUS',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalDamage: (map['totalDamage'] ?? 0.0).toDouble(),
      victorName: map['victorName'] ?? 'Unknown',
      lootDrops: List<String>.from(map['lootDrops'] ?? []),
      isSuccess: map['isSuccess'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bossName': bossName,
      'timestamp': FieldValue.serverTimestamp(),
      'totalDamage': totalDamage,
      'victorName': victorName,
      'lootDrops': lootDrops,
      'isSuccess': isSuccess,
    };
  }
}