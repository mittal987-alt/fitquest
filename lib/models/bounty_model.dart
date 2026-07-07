import 'package:cloud_firestore/cloud_firestore.dart';

class BountyModel {
  final String id;
  final String tileId;
  final double latitude;
  final double longitude;
  final DateTime expiresAt;
  final int xpReward;
  final String? itemReward; // Gear ID or Power-up ID
  final String title;

  BountyModel({
    required this.id,
    required this.tileId,
    required this.latitude,
    required this.longitude,
    required this.expiresAt,
    required this.xpReward,
    this.itemReward,
    this.title = "ANOMALY CORE",
  });

  factory BountyModel.fromMap(Map<String, dynamic> map) {
    return BountyModel(
      id: map['id'] ?? '',
      tileId: map['tileId'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      xpReward: map['xpReward'] ?? 0,
      itemReward: map['itemReward'],
      title: map['title'] ?? 'ANOMALY CORE',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tileId': tileId,
      'latitude': latitude,
      'longitude': longitude,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'xpReward': xpReward,
      'itemReward': itemReward,
      'title': title,
    };
  }
}
