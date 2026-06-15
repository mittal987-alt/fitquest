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

  // =========================
  // FROM FIREBASE
  // =========================

  factory PlayerModel.fromMap(
      Map<String, dynamic> map) {
    Map<String, DateTime> powerUps = {};
    if (map["activePowerUps"] != null) {
      (map["activePowerUps"] as Map<String, dynamic>).forEach((key, value) {
        powerUps[key] = (value as Timestamp).toDate();
      });
    }

    return PlayerModel(
      uid: map["uid"] ?? "",
      name: map["name"] ?? "",
      email: map["email"] ?? "",
      team: map["team"] ?? "No Team",
      teamId: map["teamId"],
      isInTeam: map["isInTeam"] ?? false,
      totalSteps: map["totalSteps"] ?? 0,
      totalLand: map["totalLand"] ?? 0,
      trustScore: map["trustScore"] ?? 100,
      level: map["level"] ?? 1,
      xp: map["xp"] ?? 0,
      avatar: map["avatar"] ?? "",
      lastTeamAction: map["lastTeamAction"] != null
          ? (map["lastTeamAction"] as Timestamp).toDate()
          : null,
      streakCount: map["streakCount"] ?? 0,
      lastActiveDate: map["lastActiveDate"] != null
          ? (map["lastActiveDate"] as Timestamp).toDate()
          : null,
      claimedQuests: List<String>.from(map["claimedQuests"] ?? []),
      activePowerUps: powerUps,
    );
  }

  // =========================
  // TO FIREBASE
  // =========================

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
      "lastTeamAction": lastTeamAction != null
          ? Timestamp.fromDate(lastTeamAction!)
          : null,
      "streakCount": streakCount,
      "lastActiveDate": lastActiveDate != null
          ? Timestamp.fromDate(lastActiveDate!)
          : null,
      "claimedQuests": claimedQuests,
      "activePowerUps": powerUps,
    };
  }
}
