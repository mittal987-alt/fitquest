import 'package:cloud_firestore/cloud_firestore.dart';
import 'gear_model.dart';

/// Represents a power-up configuration tracking active status and expiration.
class ActivePowerUp {
  final String powerUpId;
  final DateTime expiryTime;

  ActivePowerUp({
    required this.powerUpId,
    required this.expiryTime,
  });

  bool get isExpired => DateTime.now().isAfter(expiryTime);

  Map<String, dynamic> toMap() {
    return {
      'powerUpId': powerUpId,
      'expiryTime': Timestamp.fromDate(expiryTime),
    };
  }

  factory ActivePowerUp.fromMap(Map<String, dynamic> map) {
    return ActivePowerUp(
      powerUpId: map['powerUpId'] ?? '',
      expiryTime: map['expiryTime'] is Timestamp
          ? (map['expiryTime'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class PlayerModel {
  final String uid;
  final bool isInTeam;
  final String name;
  final String email;
  final String team;
  final String? teamId;
  final int totalSteps;
  final int dailySteps;
  final int dailyCalories;
  final double dailyDistance;
  final int lastHardwareStepCount;
  final int trustScore;
  final int level;
  final int xp;
  final int currency;
  final String avatar;
  final DateTime? lastTeamAction;
  final DateTime? lastRaidAttack;
  final int streakCount;
  final int totalRaidDamage;
  final int ghostRaidDamage;
  final DateTime? lastActiveDate;
  final List<String> claimedQuests;
  final Map<String, DateTime> activePowerUps;
  final List<String> ownedGear;
  final Map<String, String> equippedGear;

  /// Crafting inventory mapping: Material Identifier -> Inventory Volume Count
  final Map<String, int> inventory;

  /// Hourly historical step curves representing personal best segments.
  /// Map structure: "HourString" (e.g., "14" or ISO Hour) -> Accumulated steps.
  final Map<String, int> hourlySteps;

  /// Daily logs for historical tracking. Key: "YYYY-MM-DD", Value: Map of stats
  final Map<String, dynamic> dailyHistory;
  final double energyBoostRaidMultiplier;
  final double energyBoostXpMultiplier;
  final bool isGhostStriderEnabled;

  // Physical Telemetry Nodes
  final double? heightCm;
  final double? weightKg;
  final int dailyStepTarget;
  final int dailyExerciseTargetMinutes;
  final DateTime? lastSyncTime;

  // New RPG Attributes & Resource Pools
  final String? characterClass; // scout, tank, medic
  final String? fitnessGoal; // weight_loss, muscle_gain, endurance, maintenance
  final int strength;
  final int agility;
  final int endurance;
  final int currentStamina;
  final int maxStamina;

  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    double heightM = heightCm! / 100;
    return weightKg! / (heightM * heightM);
  }

  int get effectiveStrength {
    int base = strength;
    if (characterClass == 'tank') base += 5;
    return base + getModifier('strength', allGear).toInt();
  }

  int get effectiveAgility {
    int base = agility;
    if (characterClass == 'scout') base += 5;
    return base + getModifier('agility', allGear).toInt();
  }

  int get effectiveEndurance {
    int base = endurance;
    if (characterClass == 'medic') base += 5;
    return base + getModifier('endurance', allGear).toInt();
  }

  double getModifier(String key, List<GearModel> allGear) {
    double total = 1.0;
    double flatBonus = 0.0;

    equippedGear.forEach((slot, gearId) {
      try {
        final gear = allGear.firstWhere((g) => g.id == gearId);
        if (gear.modifiers.containsKey(key)) {
          final val = gear.modifiers[key]!;
          if (val > 2.0 || val < 0.5) {
            if (key == 'strength' || key == 'agility' || key == 'endurance') {
              flatBonus += val;
            } else {
              total *= val;
            }
          } else {
            total *= val;
          }
        }
      } catch (_) {}
    });

    if (key == 'strength' || key == 'agility' || key == 'endurance') {
      return flatBonus;
    }
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
    this.dailyCalories = 0,
    this.dailyDistance = 0.0,
    required this.lastHardwareStepCount,
    required this.trustScore,
    required this.level,
    required this.xp,
    this.currency = 0,
    required this.avatar,
    this.lastTeamAction,
    this.lastRaidAttack,
    this.streakCount = 0,
    this.totalRaidDamage = 0,
    this.ghostRaidDamage = 0,
    this.totalLand = 0,
    this.lastActiveDate,
    this.claimedQuests = const [],
    this.activePowerUps = const {},
    this.ownedGear = const [],
    this.equippedGear = const {},
    this.inventory = const {},
    this.hourlySteps = const {},
    this.dailyHistory = const {},
    this.energyBoostRaidMultiplier = 1.0,
    this.energyBoostXpMultiplier = 1.0,
    this.isGhostStriderEnabled = true,
    this.heightCm,
    this.weightKg,
    this.dailyStepTarget = 10000,
    this.dailyExerciseTargetMinutes = 30,
    this.lastSyncTime,
    this.characterClass,
    this.strength = 10,
    this.agility = 10,
    this.endurance = 10,
    this.currentStamina = 100,
    this.maxStamina = 100,
    this.fitnessGoal,
  });

  // FIX: totalLand is used throughout home_screen.dart (player.totalLand /
  // "AREAS VISITED" stat, the "territory_scout" quest) and passed in by
  // firebase_service.dart's createPlayer(). The field itself was missing from
  // this model entirely, which would fail to compile ("No named parameter
  // 'totalLand'" / "getter 'totalLand' isn't defined"). Declared here and
  // wired into the constructor, copyWith, fromMap, and toMap below.
  final int totalLand;

  PlayerModel copyWith({
    String? uid,
    bool? isInTeam,
    String? name,
    String? email,
    String? team,
    String? teamId,
    int? totalSteps,
    int? dailySteps,
    int? dailyCalories,
    double? dailyDistance,
    int? lastHardwareStepCount,
    int? trustScore,
    int? level,
    int? xp,
    int? currency,
    String? avatar,
    DateTime? lastTeamAction,
    DateTime? lastRaidAttack,
    int? streakCount,
    int? totalRaidDamage,
    int? ghostRaidDamage,
    int? totalLand,
    DateTime? lastActiveDate,
    List<String>? claimedQuests,
    Map<String, DateTime>? activePowerUps,
    List<String>? ownedGear,
    Map<String, String>? equippedGear,
    Map<String, int>? inventory,
    Map<String, int>? hourlySteps,
    Map<String, dynamic>? dailyHistory,
    double? energyBoostRaidMultiplier,
    double? energyBoostXpMultiplier,
    bool? isGhostStriderEnabled,
    double? heightCm,
    double? weightKg,
    int? dailyStepTarget,
    int? dailyExerciseTargetMinutes,
    DateTime? lastSyncTime,
    String? characterClass,
    String? fitnessGoal,
    int? strength,
    int? agility,
    int? endurance,
    int? currentStamina,
    int? maxStamina,
  }) {
    return PlayerModel(
      uid: uid ?? this.uid,
      isInTeam: isInTeam ?? this.isInTeam,
      name: name ?? this.name,
      email: email ?? this.email,
      team: team ?? this.team,
      teamId: teamId ?? this.teamId,
      totalSteps: totalSteps ?? this.totalSteps,
      dailySteps: dailySteps ?? this.dailySteps,
      dailyCalories: dailyCalories ?? this.dailyCalories,
      dailyDistance: dailyDistance ?? this.dailyDistance,
      lastHardwareStepCount: lastHardwareStepCount ?? this.lastHardwareStepCount,
      trustScore: trustScore ?? this.trustScore,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      currency: currency ?? this.currency,
      avatar: avatar ?? this.avatar,
      lastTeamAction: lastTeamAction ?? this.lastTeamAction,
      lastRaidAttack: lastRaidAttack ?? this.lastRaidAttack,
      streakCount: streakCount ?? this.streakCount,
      totalRaidDamage: totalRaidDamage ?? this.totalRaidDamage,
      ghostRaidDamage: ghostRaidDamage ?? this.ghostRaidDamage,
      totalLand: totalLand ?? this.totalLand,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      claimedQuests: claimedQuests ?? this.claimedQuests,
      activePowerUps: activePowerUps ?? this.activePowerUps,
      ownedGear: ownedGear ?? this.ownedGear,
      equippedGear: equippedGear ?? this.equippedGear,
      inventory: inventory ?? this.inventory,
      hourlySteps: hourlySteps ?? this.hourlySteps,
      dailyHistory: dailyHistory ?? this.dailyHistory,
      energyBoostRaidMultiplier: energyBoostRaidMultiplier ?? this.energyBoostRaidMultiplier,
      energyBoostXpMultiplier: energyBoostXpMultiplier ?? this.energyBoostXpMultiplier,
      isGhostStriderEnabled: isGhostStriderEnabled ?? this.isGhostStriderEnabled,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      dailyStepTarget: dailyStepTarget ?? this.dailyStepTarget,
      dailyExerciseTargetMinutes: dailyExerciseTargetMinutes ?? this.dailyExerciseTargetMinutes,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      characterClass: characterClass ?? this.characterClass,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      strength: strength ?? this.strength,
      agility: agility ?? this.agility,
      endurance: endurance ?? this.endurance,
      currentStamina: currentStamina ?? this.currentStamina,
      maxStamina: maxStamina ?? this.maxStamina,
    );
  }

  factory PlayerModel.fromMap(Map<String, dynamic> map) {
    Map<String, DateTime> powerUps = {};
    if (map["activePowerUps"] != null) {
      (map["activePowerUps"] as Map<String, dynamic>).forEach((key, value) {
        if (value is Timestamp) {
          powerUps[key] = value.toDate();
        } else if (value is String) {
          powerUps[key] = DateTime.parse(value);
        }
      });
    }

    return PlayerModel(
      uid: map["uid"]?.toString() ?? "",
      name: map["name"]?.toString() ?? "New Player",
      email: map["email"]?.toString() ?? "",
      team: map["team"]?.toString() ?? "No Team",
      teamId: map["teamId"]?.toString(),
      isInTeam: map["isInTeam"] is bool ? map["isInTeam"] : false,
      totalSteps: (map["totalSteps"] as num?)?.toInt() ?? 0,
      dailySteps: (map["dailySteps"] as num?)?.toInt() ?? 0,
      dailyCalories: (map["dailyCalories"] as num?)?.toInt() ?? 0,
      dailyDistance: (map["dailyDistance"] as num?)?.toDouble() ?? 0.0,
      lastHardwareStepCount: (map["lastHardwareStepCount"] as num?)?.toInt() ?? -1,
      trustScore: (map["trustScore"] as num?)?.toInt() ?? 100,
      level: (map["level"] as num?)?.toInt() ?? 1,
      xp: (map["xp"] as num?)?.toInt() ?? 0,
      currency: (map["currency"] as num?)?.toInt() ?? 0,
      avatar: map["avatar"]?.toString() ?? "",
      lastTeamAction: map["lastTeamAction"] is Timestamp ? (map["lastTeamAction"] as Timestamp).toDate() : null,
      lastRaidAttack: map["lastRaidAttack"] is Timestamp ? (map["lastRaidAttack"] as Timestamp).toDate() : null,
      streakCount: (map["streakCount"] as num?)?.toInt() ?? 0,
      totalRaidDamage: (map["totalRaidDamage"] as num?)?.toInt() ?? 0,
      ghostRaidDamage: (map["ghostRaidDamage"] as num?)?.toInt() ?? 0,
      totalLand: (map["totalLand"] as num?)?.toInt() ?? 0,
      lastActiveDate: map["lastActiveDate"] is Timestamp ? (map["lastActiveDate"] as Timestamp).toDate() : null,
      claimedQuests: map["claimedQuests"] != null ? List<String>.from(map["claimedQuests"]) : const [],
      activePowerUps: powerUps,
      ownedGear: map["ownedGear"] != null ? List<String>.from(map["ownedGear"]) : const [],
      equippedGear: Map<String, String>.from(map["equippedGear"] ?? {}),
      inventory: Map<String, int>.from(map['inventory'] ?? {}),
      hourlySteps: Map<String, int>.from(map['hourlySteps'] ?? map['hourlyTelemetry'] ?? {}),
      dailyHistory: Map<String, dynamic>.from(map['dailyHistory'] ?? {}),
      energyBoostRaidMultiplier: (map["energyBoostRaidMultiplier"] as num?)?.toDouble() ?? (map["rechargeRaidMultiplier"] as num?)?.toDouble() ?? 1.0,
      energyBoostXpMultiplier: (map["energyBoostXpMultiplier"] as num?)?.toDouble() ?? (map["rechargeXpMultiplier"] as num?)?.toDouble() ?? 1.0,
      isGhostStriderEnabled: map["isGhostStriderEnabled"] is bool ? map["isGhostStriderEnabled"] : true,
      heightCm: (map["heightCm"] as num?)?.toDouble(),
      weightKg: (map["weightKg"] as num?)?.toDouble(),
      dailyStepTarget: (map["dailyStepTarget"] as num?)?.toInt() ?? 10000,
      dailyExerciseTargetMinutes: (map["dailyExerciseTargetMinutes"] as num?)?.toInt() ?? 30,
      lastSyncTime: map["lastSyncTime"] is Timestamp ? (map["lastSyncTime"] as Timestamp).toDate() : (map["lastSyncTime"] is String ? DateTime.parse(map["lastSyncTime"]) : null),
      characterClass: map["characterClass"]?.toString(),
      fitnessGoal: map["fitnessGoal"]?.toString(),
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
      "dailyCalories": dailyCalories,
      "dailyDistance": dailyDistance,
      "lastHardwareStepCount": lastHardwareStepCount,
      "trustScore": trustScore,
      "level": level,
      "isInTeam": isInTeam,
      "xp": xp,
      "currency": currency,
      "avatar": avatar,
      "lastTeamAction": lastTeamAction != null ? Timestamp.fromDate(lastTeamAction!) : null,
      "lastRaidAttack": lastRaidAttack != null ? Timestamp.fromDate(lastRaidAttack!) : null,
      "streakCount": streakCount,
      "totalRaidDamage": totalRaidDamage,
      "ghostRaidDamage": ghostRaidDamage,
      "totalLand": totalLand,
      "lastActiveDate": lastActiveDate != null ? Timestamp.fromDate(lastActiveDate!) : null,
      "claimedQuests": claimedQuests,
      "activePowerUps": powerUps,
      "ownedGear": ownedGear,
      "equippedGear": equippedGear,
      "inventory": inventory,
      "hourlySteps": hourlySteps,
      "dailyHistory": dailyHistory,
      "energyBoostRaidMultiplier": energyBoostRaidMultiplier,
      "energyBoostXpMultiplier": energyBoostXpMultiplier,
      "isGhostStriderEnabled": isGhostStriderEnabled,
      "heightCm": heightCm,
      "weightKg": weightKg,
      "dailyStepTarget": dailyStepTarget,
      "dailyExerciseTargetMinutes": dailyExerciseTargetMinutes,
      "lastSyncTime": lastSyncTime != null ? Timestamp.fromDate(lastSyncTime!) : null,
      "characterClass": characterClass,
      "fitnessGoal": fitnessGoal,
      "strength": strength,
      "agility": agility,
      "endurance": endurance,
      "currentStamina": currentStamina,
      "maxStamina": maxStamina,
    };
  }
}