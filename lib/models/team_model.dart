import 'package:flutter/material.dart';

class TeamModel {
  final String id;
  final String name;
  final String color;
  final bool strongholdActive;
  final int members;
  final int maxMembers;
  final int totalSteps;
  final double totalRaidDamage;
  final String leaderId;
  final String logo;
  final List<String> strongholdClusters;
  final double raidBossHp;

  TeamModel({
    required this.id,
    required this.name,
    required this.color,
    required this.members,
    required this.maxMembers,
    required this.totalSteps,
    this.totalRaidDamage = 0.0,
    required this.leaderId,
    required this.strongholdActive,
    required this.logo,
    this.strongholdClusters = const [],
    this.raidBossHp = 100000.0,
  });

  // =========================
  // FROM FIREBASE
  // =========================
  factory TeamModel.fromMap(Map<String, dynamic> map) {
    return TeamModel(
      id: map["id"] ?? "",
      name: map["name"] ?? "",
      color: map["color"] ?? "blue",
      members: map["members"] ?? 0,
      maxMembers: map["maxMembers"] ?? 50,
      totalSteps: map["totalSteps"] ?? 0,
      totalRaidDamage: (map["totalRaidDamage"] ?? 0.0).toDouble(),
      strongholdActive: map['strongholdActive'] ?? false,
      leaderId: map["leaderId"] ?? "",
      logo: map["logo"] ?? "",
      strongholdClusters: map["strongholdClusters"] != null
          ? List<String>.from(map["strongholdClusters"])
          : const [],
      raidBossHp: (map["raidBossHp"] ?? 100000.0).toDouble(),
    );
  }

  // =========================
  // TO FIREBASE
  // =========================
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "color": color,
      "members": members,
      "maxMembers": maxMembers,
      "totalSteps": totalSteps,
      "totalRaidDamage": totalRaidDamage,
      "leaderId": leaderId,
      "logo": logo,
      "strongholdActive": strongholdActive,
      "strongholdClusters": strongholdClusters,
      "raidBossHp": raidBossHp,
    };
  }

  // =========================
  // TEAM COLOR
  // =========================
  Color getTeamColor() {
    switch (color) {
      case "red":
        return Colors.red;
      case "green":
        return Colors.green;
      case "yellow":
        return Colors.orange;
      case "purple":
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}
