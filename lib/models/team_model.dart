import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  final String id;
  final String name;
  final String color;
  final bool strongholdActive;
  final int members;
  final int maxMembers;
  final int totalSteps;
  final int dailySteps;
  final int weeklySteps;
  final int territoryCount;
  final int teamCurrency;
  final DateTime? lastDailyReset;
  final String? activeDailyChallengeId;
  final double totalRaidDamage;
  final String leaderId;
  final String logo;
  final List<String> unlockedAchievements;
  final List<String> strongholdClusters;
  final double raidBossHp;
  final String? raidBossId;
  final Map<String, DateTime> synergyResonance; // Class -> Expiry
  final Map<String, DateTime> activeTeamBuffs; // BuffId -> Expiry

  TeamModel({
    required this.id,
    required this.name,
    required this.color,
    required this.members,
    required this.maxMembers,
    required this.totalSteps,
    this.dailySteps = 0,
    this.weeklySteps = 0,
    this.territoryCount = 0,
    this.teamCurrency = 0,
    this.lastDailyReset,
    this.activeDailyChallengeId,
    this.totalRaidDamage = 0.0,
    required this.leaderId,
    required this.strongholdActive,
    required this.logo,
    this.unlockedAchievements = const [],
    this.strongholdClusters = const [],
    this.raidBossHp = 100000.0,
    this.raidBossId,
    this.synergyResonance = const {},
    this.activeTeamBuffs = const {},
  });

  // =========================
  // FROM FIREBASE
  // =========================
  factory TeamModel.fromMap(Map<String, dynamic> map) {
    Map<String, DateTime> resonance = {};
    if (map["synergyResonance"] != null) {
      (map["synergyResonance"] as Map<String, dynamic>).forEach((key, value) {
        if (value is Timestamp) resonance[key] = value.toDate();
      });
    }

    Map<String, DateTime> buffs = {};
    if (map["activeTeamBuffs"] != null) {
      (map["activeTeamBuffs"] as Map<String, dynamic>).forEach((key, value) {
        if (value is Timestamp) buffs[key] = value.toDate();
      });
    }

    return TeamModel(
      id: map["id"] ?? "",
      name: map["name"] ?? "",
      color: map["color"] ?? "blue",
      members: (map["members"] as num?)?.toInt() ?? 0,
      maxMembers: (map["maxMembers"] as num?)?.toInt() ?? 50,
      totalSteps: (map["totalSteps"] as num?)?.toInt() ?? 0,
      dailySteps: (map["dailySteps"] as num?)?.toInt() ?? 0,
      weeklySteps: (map["weeklySteps"] as num?)?.toInt() ?? 0,
      territoryCount: (map["territoryCount"] as num?)?.toInt() ?? 0,
      teamCurrency: (map["teamCurrency"] as num?)?.toInt() ?? 0,
      lastDailyReset: map["lastDailyReset"] != null ? (map["lastDailyReset"] as Timestamp).toDate() : null,
      activeDailyChallengeId: map["activeDailyChallengeId"],
      totalRaidDamage: (map["totalRaidDamage"] ?? 0.0).toDouble(),
      strongholdActive: map['strongholdActive'] ?? false,
      leaderId: map["leaderId"] ?? "",
      logo: map["logo"] ?? "",
      unlockedAchievements: map["unlockedAchievements"] != null
          ? List<String>.from(map["unlockedAchievements"])
          : const [],
      strongholdClusters: map["strongholdClusters"] != null
          ? List<String>.from(map["strongholdClusters"])
          : const [],
      raidBossHp: (map["raidBossHp"] ?? 100000.0).toDouble(),
      raidBossId: map["raidBossId"]?.toString(),
      synergyResonance: resonance,
      activeTeamBuffs: buffs,
    );
  }

  // =========================
  // TO FIREBASE
  // =========================
  Map<String, dynamic> toMap() {
    Map<String, Timestamp> resonance = {};
    synergyResonance.forEach((key, value) {
      resonance[key] = Timestamp.fromDate(value);
    });

    Map<String, Timestamp> buffs = {};
    activeTeamBuffs.forEach((key, value) {
      buffs[key] = Timestamp.fromDate(value);
    });

    return {
      "id": id,
      "name": name,
      "color": color,
      "members": members,
      "maxMembers": maxMembers,
      "totalSteps": totalSteps,
      "dailySteps": dailySteps,
      "weeklySteps": weeklySteps,
      "territoryCount": territoryCount,
      "teamCurrency": teamCurrency,
      "lastDailyReset": lastDailyReset != null ? Timestamp.fromDate(lastDailyReset!) : null,
      "activeDailyChallengeId": activeDailyChallengeId,
      "totalRaidDamage": totalRaidDamage,
      "leaderId": leaderId,
      "logo": logo,
      "unlockedAchievements": unlockedAchievements,
      "strongholdActive": strongholdActive,
      "strongholdClusters": strongholdClusters,
      "raidBossHp": raidBossHp,
      "raidBossId": raidBossId,
      "synergyResonance": resonance,
      "activeTeamBuffs": buffs,
    };
  }

  // =========================
  // CALCULATED STATS
  // =========================
  double get stepEfficiency => totalSteps / (members > 0 ? members : 1);

  // =========================
  // TEAM COLOR
  // =========================
  Color getTeamColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (color) {
      case "red":
        return colorScheme.error;
      case "green":
        return Colors.green;
      case "yellow":
        return colorScheme.tertiary;
      case "purple":
        return Colors.purple;
      case "blue":
        return colorScheme.primary;
      case "orange":
        return colorScheme.secondary;
      default:
        return colorScheme.primary;
    }
  }
}