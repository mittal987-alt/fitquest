import 'package:cloud_firestore/cloud_firestore.dart';

class HexTileModel {
  final String tileId;
  final double latitude;
  final double longitude;

  // =========================
  // OWNER
  // =========================

  final String ownerType; // solo OR team
  final String ownerId; // player uid OR team id
  final String ownerName; // player/team name

  final String color;
  final int power;
  final int capturedAt;

  HexTileModel({
    required this.tileId,
    required this.latitude,
    required this.longitude,
    required this.ownerType,
    required this.ownerId,
    required this.ownerName,
    required this.color,
    required this.power,
    required this.capturedAt,
  });

  // =========================
  // TO FIRESTORE
  // =========================

  Map<String, dynamic> toMap() {
    return {
      "tileId": tileId,
      "latitude": latitude,
      "longitude": longitude,
      "ownerType": ownerType,
      "ownerId": ownerId,
      "ownerName": ownerName,
      "color": color,
      "power": power,

      // Save as Firestore Timestamp
      "capturedAt":
      Timestamp.fromMillisecondsSinceEpoch(capturedAt),
    };
  }

  // =========================
  // FROM FIRESTORE
  // =========================

  factory HexTileModel.fromMap(Map<String, dynamic> map) {
    int capturedTime = 0;

    final capturedAtData = map["capturedAt"];

    if (capturedAtData is Timestamp) {
      capturedTime =
          capturedAtData.millisecondsSinceEpoch;
    } else if (capturedAtData is int) {
      capturedTime = capturedAtData;
    } else if (capturedAtData is String) {
      capturedTime = int.tryParse(capturedAtData) ?? 0;
    }

    return HexTileModel(
      tileId: map["tileId"] ?? "",
      latitude: (map["latitude"] ?? 0.0).toDouble(),
      longitude: (map["longitude"] ?? 0.0).toDouble(),
      ownerType: map["ownerType"] ?? "solo",
      ownerId: map["ownerId"] ?? "",
      ownerName: map["ownerName"] ?? "Unknown",
      color: map["color"] ?? "grey",
      power: map["power"] ?? 0,
      capturedAt: capturedTime,
    );
  }
}
