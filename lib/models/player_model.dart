import 'package:cloud_firestore/cloud_firestore.dart';
import 'gear_model.dart';

class PlayerModel {
  final String uid;
  final bool isInTeam;
  final String name;
  final String email;
  final String team;
  final String? teamId;
  final int totalSteps;
  final int dailySteps;
  final int lastHardwareStepCount;
  final int totalLand;
  final int trustScore;
  final int level;
  final int xp;
  final String avatar;
  final DateTime? lastTeamAction;
  final int streakCount;
  final DateTime? lastActiveDate;
  final List<String> claimedQuests;
  final Map<String, DateTime> activePowerUps;
  final List<String> ownedGear;
  final Map<String, String> equippedGear;

  // Physical Telemetry Nodes
  final double? heightCm;
  final double? weightKg;
  final int dailyStepTarget;
  final int dailyExerciseTargetMinutes;

  // New RPG Attributes & Resource Pools
  final int strength;
  final int agility;
  final int endurance;
  final int currentStamina;
  final int maxStamina;

  double getModifier(String key, List<GearModel> allGear) {
    double total = 1.0;
    equippedGear.forEach((slot, gearId) {
      try {
        final gear = allGear.firstWhere((g) => g.id == gearId);
        if (gear.modifiers.containsKey(key)) {
          total *= gear.modifiers[key]!;
        }
      } catch (_) {}
    });
    return total;
  }

  PlayerModel({
    required this.uid,
    required this.name,
    required this.isInTeam,
    required this.email,
    required this.team,
    this.teamId,
    required this.totalSteps,
    required this.dailySteps,
    required this.lastHardwareStepCount,
    required this.totalLand,
    required this.trustScore,
    required this.level,
    required this.xp,
    required this.avatar,
    this.lastTeamAction,
    this.streakCount = 0,
    this.lastActiveDate,
    this.claimedQuests = const [],
    this.activePowerUps = const {},
    this.ownedGear = const [],
    this.equippedGear = const {},
    this.heightCm,
    this.weightKg,
    this.dailyStepTarget = 10000,
    this.dailyExerciseTargetMinutes = 30,
    this.strength = 10,
    this.agility = 10,
    this.endurance = 10,
    this.currentStamina = 100,
    this.maxStamina = 100,
  });

  factory PlayerModel.fromMap(Map<String, dynamic> map) {
    Map<String, DateTime> powerUps = {};
    if (map["activePowerUps"] != null) {
      (map["activePowerUps"] as Map<String, dynamic>).forEach((key, value) {
        if (value is Timestamp) {
          powerUps[key] = value.toDate();
        }
      });
    }

    return PlayerModel(
      uid: map["uid"]?.toString() ?? "",
      name: map["name"]?.toString() ?? "",
      email: map["email"]?.toString() ?? "",
      team: map["team"]?.toString() ?? "No Team",
      teamId: map["teamId"]?.toString(),
      isInTeam: map["isInTeam"] is bool ? map["isInTeam"] : false,
      totalSteps: (map["totalSteps"] as num?)?.toInt() ?? 0,
      dailySteps: (map["dailySteps"] as num?)?.toInt() ?? 0,
      lastHardwareStepCount: (map["lastHardwareStepCount"] as num?)?.toInt() ?? -1,
      totalLand: (map["totalLand"] as num?)?.toInt() ?? 0,
      trustScore: (map["trustScore"] as num?)?.toInt() ?? 100,
      level: (map["level"] as num?)?.toInt() ?? 1,
      xp: (map["xp"] as num?)?.toInt() ?? 0,
      avatar: map["avatar"]?.toString() ?? "",
      lastTeamAction: map["lastTeamAction"] is Timestamp ? (map["lastTeamAction"] as Timestamp).toDate() : null,
      streakCount: (map["streakCount"] as num?)?.toInt() ?? 0,
      lastActiveDate: map["lastActiveDate"] is Timestamp ? (map["lastActiveDate"] as Timestamp).toDate() : null,
      claimedQuests: map["claimedQuests"] != null ? List<String>.from(map["claimedQuests"]) : const [],
      activePowerUps: powerUps,
      ownedGear: map["ownedGear"] != null ? List<String>.from(map["ownedGear"]) : const [],
      equippedGear: Map<String, String>.from(map["equippedGear"] ?? {}),
      heightCm: (map["heightCm"] as num?)?.toDouble(),
      weightKg: (map["weightKg"] as num?)?.toDouble(),
      dailyStepTarget: (map["dailyStepTarget"] as num?)?.toInt() ?? 10000,
      dailyExerciseTargetMinutes: (map["dailyExerciseTargetMinutes"] as num?)?.toInt() ?? 30,
      strength: (map["strength"] as num?)?.toInt() ?? 10,
      agility: (map["agility"] as num?)?.toInt() ?? 10,
      endurance: (map["endurance"] as num?)?.toInt() ?? 10,
      currentStamina: (map["currentStamina"] as num?)?.toInt() ?? 100,
      maxStamina: (map["maxStamina"] as num?)?.toInt() ?? 100,
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, Timestamp> powerUps = {};
    activePowerUps.forEach((key, value) {
      powerUps[key] = Timestamp.fromDate(value);
    });

    return {
      "uid": uid,
      "name": name,
      "email": email,
      "team": team,
      "teamId": teamId,
      "totalSteps": totalSteps,
      "dailySteps": dailySteps,
      "lastHardwareStepCount": lastHardwareStepCount,
      "totalLand": totalLand,
      "trustScore": trustScore,
      "level": level,
      "isInTeam": isInTeam,
      "xp": xp,
      "avatar": avatar,
      "lastTeamAction": lastTeamAction != null ? Timestamp.fromDate(lastTeamAction!) : null,
      "streakCount": streakCount,
      "lastActiveDate": lastActiveDate != null ? Timestamp.fromDate(lastActiveDate!) : null,
      "claimedQuests": claimedQuests,
      "activePowerUps": powerUps,
      "ownedGear": ownedGear,
      "equippedGear": equippedGear,
      "heightCm": heightCm,
      "weightKg": weightKg,
      "dailyStepTarget": dailyStepTarget,
      "dailyExerciseTargetMinutes": dailyExerciseTargetMinutes,
      "strength": strength,
      "agility": agility,
      "endurance": endurance,
      "currentStamina": currentStamina,
      "maxStamina": maxStamina,
    };
  }
}