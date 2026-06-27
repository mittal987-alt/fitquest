import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerModel {
  final String uid;
  final bool isInTeam;
  final String name;
  final String email;
  final String team;
  final String? teamId;
  final int totalSteps;
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

  PlayerModel({
    required this.uid,
    required this.name,
    required this.isInTeam,
    required this.email,
    required this.team,
    this.teamId,
    required this.totalSteps,
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
      totalLand: (map["totalLand"] as num?)?.toInt() ?? 0,
      trustScore: (map["trustScore"] as num?)?.toInt() ?? 100,
      level: (map["level"] as num?)?.toInt() ?? 1,
      xp: (map["xp"] as num?)?.toInt() ?? 0,
      avatar: map["avatar"]?.toString() ?? "",
      lastTeamAction: map["lastTeamAction"] is Timestamp
          ? (map["lastTeamAction"] as Timestamp).toDate()
          : null,
      streakCount: (map["streakCount"] as num?)?.toInt() ?? 0,
      lastActiveDate: map["lastActiveDate"] is Timestamp
          ? (map["lastActiveDate"] as Timestamp).toDate()
          : null,
      claimedQuests: map["claimedQuests"] != null
          ? List<String>.from(map["claimedQuests"])
          : const [],
      activePowerUps: powerUps,
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
    };
  }
}