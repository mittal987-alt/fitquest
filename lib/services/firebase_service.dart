import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../models/hex_tile_model.dart';
import '../models/team_request_model.dart';

class FirebaseService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // =========================
  // CURRENT USER
  // =========================
  User? get currentUser => auth.currentUser;

  // =========================
  // RANK LOGIC
  // =========================
  String getRankTitle(int level) {
    if (level < 5) return "RECRUIT";
    if (level < 15) return "OPERATOR";
    if (level < 30) return "VETERAN";
    if (level < 50) return "COMMANDER";
    return "APEX LEGEND";
  }

  // =========================
  // CREATE PLAYER
  // =========================
  Future<void> createPlayer({
    required String uid,
    required String name,
    required String email,
  }) async {
    PlayerModel player = PlayerModel(
      uid: uid,
      name: name,
      email: email,
      team: "No Team",
      teamId: null,
      isInTeam: false,
      totalSteps: 0,
      dailySteps: 0,
      lastHardwareStepCount: -1,
      totalLand: 0,
      trustScore: 100,
      level: 1,
      xp: 0,
      avatar: "",
    );

    await firestore.collection("players").doc(uid).set(player.toMap());
  }

  // =========================
  // GET PLAYER
  // =========================
  Future<PlayerModel?> getPlayer(String uid) async {
    try {
      final doc = await firestore.collection("players").doc(uid).get();
      if (!doc.exists) return null;
      return PlayerModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // =========================
  // PLAYER STREAM
  // =========================
  Stream<PlayerModel?> getPlayerStream(String uid) {
    return firestore.collection("players").doc(uid).snapshots().map((doc) {
      try {
        if (!doc.exists) return null;
        return PlayerModel.fromMap(doc.data()!);
      } catch (e) {
        return null;
      }
    });
  }

  // =========================
  // UPDATE TEAM STATUS
  // =========================
  Future<void> updateTeamStatus({
    required String uid,
    required bool isInTeam,
  }) async {
    await firestore.collection("players").doc(uid).update({
      "isInTeam": isInTeam,
    });
  }

  // =========================
  // UPDATE STEPS
  // =========================
  Future<void> updateSteps({
    required String uid,
    required int stepsToAdd,
  }) async {
    try {
      await firestore.collection("players").doc(uid).update({
        "totalSteps": FieldValue.increment(stepsToAdd),
        "dailySteps": FieldValue.increment(stepsToAdd),
      });
      debugPrint("STEPS UPDATED => +$stepsToAdd");
    } catch (e) {
      debugPrint("STEP UPDATE ERROR => $e");
    }
  }

  // =========================
  // UPDATE LAND
  // =========================
  Future<void> updateLand({
    required String uid,
    required int totalLand,
  }) async {
    try {
      await firestore.collection("players").doc(uid).update({
        "totalLand": totalLand,
      });
      debugPrint("LAND UPDATED => $totalLand");
    } catch (e) {
      debugPrint("LAND UPDATE ERROR => $e");
    }
  }

  // =========================
  // UPDATE TRUST SCORE
  // =========================
  Future<void> updateTrustScore({
    required String uid,
    required int trustScore,
  }) async {
    await firestore.collection("players").doc(uid).update({
      "trustScore": trustScore,
    });
  }

  // =========================
  // UPDATE XP & LEVEL
  // =========================
  Future<void> incrementXP({
    required String uid,
    required int xpToAdd,
  }) async {
    final docRef = firestore.collection("players").doc(uid);

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      int currentXp = data["xp"] ?? 0;
      int currentLevel = data["level"] ?? 1;

      // Apply XP Booster if active
      int finalXpToAdd = xpToAdd;
      Map<String, dynamic> activePowerUps = Map<String, dynamic>.from(data["activePowerUps"] ?? {});
      if (activePowerUps.containsKey("boost")) {
        Timestamp expiry = activePowerUps["boost"] as Timestamp;
        if (expiry.toDate().isAfter(DateTime.now())) {
          finalXpToAdd = (xpToAdd * 2);
        }
      }

      int newXp = currentXp + finalXpToAdd;
      int newLevel = (newXp ~/ 1000) + 1;

      Map<String, dynamic> updates = {"xp": newXp};
      if (newLevel > currentLevel) {
        updates["level"] = newLevel;
      }

      transaction.update(docRef, updates);
      debugPrint("XP INCREMENTED: $xpToAdd (Final: $finalXpToAdd) -> New XP: $newXp, Level: $newLevel");
    });
  }

  // =========================
  // UPDATE STREAK & RESET QUESTS
  // =========================
  Future<void> checkAndResetDailyStats(String uid) async {
    final doc = await firestore.collection("players").doc(uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final lastActiveDate = data["lastActiveDate"] != null
        ? (data["lastActiveDate"] as Timestamp).toDate()
        : null;
    int currentStreak = data["streakCount"] ?? 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastActiveDate == null) {
      await firestore.collection("players").doc(uid).update({
        "streakCount": 1,
        "lastActiveDate": Timestamp.fromDate(today),
        "claimedQuests": [],
      });
    } else {
      final lastDate = DateTime(lastActiveDate.year, lastActiveDate.month, lastActiveDate.day);
      final difference = today.difference(lastDate).inDays;

      if (difference >= 1) {
        Map<String, dynamic> updates = {
          "lastActiveDate": Timestamp.fromDate(today),
          "claimedQuests": [],
          "dailySteps": 0,
        };

        if (difference == 1) {
          updates["streakCount"] = currentStreak + 1;
        } else {
          updates["streakCount"] = 1;
        }
        await firestore.collection("players").doc(uid).update(updates);
      }
    }
  }

  // =========================
  // CLAIM QUEST
  // =========================
  Future<void> claimQuest({
    required String uid,
    required String questId,
    required int rewardXp,
  }) async {
    final docRef = firestore.collection("players").doc(uid);

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      List<String> claimed = List<String>.from(data["claimedQuests"] ?? []);
      int currentXp = data["xp"] ?? 0;
      int currentLevel = data["level"] ?? 1;

      if (!claimed.contains(questId)) {
        claimed.add(questId);
        
        int newXp = currentXp + rewardXp;
        int newLevel = (newXp ~/ 1000) + 1;

        Map<String, dynamic> updates = {
          "claimedQuests": claimed,
          "xp": newXp,
        };
        
        if (newLevel > currentLevel) {
          updates["level"] = newLevel;
        }
        
        transaction.update(docRef, updates);
      }
    });
  }

  // =========================
  // UPDATE LEVEL
  // =========================
  Future<void> updateLevel({
    required String uid,
    required int level,
  }) async {
    await firestore.collection("players").doc(uid).update({
      "level": level,
    });
  }

  // =========================
  // UPDATE AVATAR
  // =========================
  Future<void> updateAvatar({
    required String uid,
    required String avatarUrl,
  }) async {
    await firestore.collection("players").doc(uid).update({
      "avatar": avatarUrl,
    });
  }

  // =========================
  // GLOBAL LEADERBOARD
  // =========================
  Stream<List<PlayerModel>> getLeaderboard() {
    return firestore
        .collection("players")
        .orderBy("totalSteps", descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PlayerModel.fromMap(doc.data())).toList();
    });
  }

  // =========================
  // SOLO LEADERBOARD
  // =========================
  Stream<List<PlayerModel>> getSoloLeaderboard() {
    return firestore
        .collection("players")
        .orderBy("totalSteps", descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PlayerModel.fromMap(doc.data())).toList();
    });
  }

  // =========================
  // TEAM LEADERBOARD
  // =========================
  Stream<List<PlayerModel>> getTeamLeaderboard(String teamName) {
    return firestore
        .collection("players")
        .where("team", isEqualTo: teamName)
        .snapshots()
        .map((snapshot) {
      final players = snapshot.docs
          .map((doc) => PlayerModel.fromMap(doc.data()))
          .toList();

      players.sort((a, b) => b.totalSteps.compareTo(a.totalSteps));
      return players;
    });
  }

  // =========================
  // CREATE TEAM
  // =========================
  Future<void> createTeam(TeamModel team) async {
    await firestore.collection("teams").doc(team.id).set(team.toMap());

    await firestore.collection("players").doc(team.leaderId).update({
      "team": team.name,
      "teamId": team.id,
      "isInTeam": true,
      "lastTeamAction": FieldValue.serverTimestamp(),
    });
  }

  // =========================
  // GET TEAMS FOR LEADERBOARD
  // =========================
  Stream<List<TeamModel>> getTeamLeaderboardGlobal() {
    return firestore
        .collection("teams")
        .orderBy("totalSteps", descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TeamModel.fromMap(doc.data())).toList();
    });
  }

  Stream<List<TeamModel>> getTeams() {
    return firestore.collection("teams").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TeamModel.fromMap(doc.data())).toList();
    });
  }

  // =========================
  // JOIN TEAM
  // =========================
  Future<void> joinTeam({
    required String uid,
    required String teamId,
    required String teamName,
  }) async {
    await firestore.collection("players").doc(uid).update({
      "team": teamName,
      "teamId": teamId,
      "isInTeam": true,
    });
  }

  // =========================
  // UPDATE TEAM LAND
  // =========================
  Future<void> updateTeamLand({
    required String teamId,
    required int totalLand,
  }) async {
    await firestore.collection("teams").doc(teamId).update({
      "totalLand": totalLand,
    });
  }

  // =========================
  // UPDATE TEAM STEPS
  // =========================
  Future<void> updateTeamSteps({
    required String teamId,
    required int stepsToAdd,
  }) async {
    await firestore.collection("teams").doc(teamId).update({
      "totalSteps": FieldValue.increment(stepsToAdd),
    });
  }

  // =========================
  // UPDATE TEAM MEMBERS
  // =========================
  Future<void> updateTeamMembers({
    required String teamId,
    required int members,
  }) async {
    await firestore.collection("teams").doc(teamId).update({
      "members": members,
    });
  }

  // =========================
  // SAVE HEX TILE
  // =========================
  Future<void> saveHexTile(HexTileModel tile) async {
    try {
      debugPrint("START FIREBASE WRITE");
      await firestore.collection("hex_tiles").doc(tile.tileId).set(tile.toMap());
      debugPrint("FIREBASE WRITE SUCCESS");
    } catch (e, s) {
      debugPrint("FIREBASE ERROR = $e");
      debugPrint("$s");
    }
  }

  // =========================
  // GET HEX TILES
  // =========================
  Stream<List<HexTileModel>> getHexTiles() {
    return firestore.collection("hex_tiles").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => HexTileModel.fromMap(doc.data())).toList();
    });
  }

  // =========================
  // DELETE HEX TILE
  // =========================
  Future<void> deleteHexTile(String tileId) async {
    await firestore.collection("hex_tiles").doc(tileId).delete();
  }

  // =========================
  // SEND JOIN REQUEST
  // =========================
  Future<void> sendJoinRequest(TeamRequestModel request) async {
    await firestore.collection("team_requests").doc(request.requestId).set(request.toMap());
  }

  // =========================
  // GET TEAM REQUESTS
  // =========================
  Stream<List<TeamRequestModel>> getTeamRequests(String teamId) {
    return firestore
        .collection("team_requests")
        .where("teamId", isEqualTo: teamId)
        .where("status", isEqualTo: "pending")
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TeamRequestModel.fromMap(doc.data())).toList();
    });
  }

  // =========================
  // ACCEPT REQUEST
  // =========================
  Future<void> acceptRequest({
    required String requestId,
    required String playerId,
    required String teamId,
    required String teamName,
  }) async {
    await firestore.collection("players").doc(playerId).update({
      "team": teamName,
      "teamId": teamId,
      "isInTeam": true,
      "lastTeamAction": FieldValue.serverTimestamp(),
    });

    await firestore.collection("team_requests").doc(requestId).update({
      "status": "accepted",
    });

    DocumentSnapshot teamDoc = await firestore.collection("teams").doc(teamId).get();
    int currentMembers = teamDoc["members"];
    await firestore.collection("teams").doc(teamId).update({
      "members": currentMembers + 1,
    });
  }

  // =========================
  // LEAVE / KICK / REJECT
  // =========================
  Future<void> leaveTeam({
    required String uid,
    required String teamId,
  }) async {
    DocumentSnapshot teamDoc = await firestore.collection("teams").doc(teamId).get();

    await firestore.collection("players").doc(uid).update({
      "team": "No Team",
      "teamId": null,
      "isInTeam": false,
      "lastTeamAction": FieldValue.serverTimestamp(),
    });

    int currentMembers = teamDoc["members"];
    if (currentMembers > 0) {
      await firestore.collection("teams").doc(teamId).update({
        "members": currentMembers - 1,
      });
    }
  }

  Future<void> kickPlayer({
    required String playerId,
    required String teamId,
  }) async {
    await firestore.collection("players").doc(playerId).update({
      "team": "No Team",
      "isInTeam": false,
      "lastTeamAction": FieldValue.serverTimestamp(),
    });

    DocumentSnapshot teamDoc = await firestore.collection("teams").doc(teamId).get();
    int currentMembers = teamDoc["members"];
    if (currentMembers > 0) {
      await firestore.collection("teams").doc(teamId).update({
        "members": currentMembers - 1,
      });
    }
  }

  Future<void> rejectRequest(String requestId) async {
    await firestore.collection("team_requests").doc(requestId).update({
      "status": "rejected",
    });
  }

  // =========================
  // PURCHASE POWER-UP
  // =========================
  Future<void> purchasePowerUp({
    required String uid,
    required String powerUpId,
    required int cost,
    required Duration duration,
  }) async {
    final docRef = firestore.collection("players").doc(uid);

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      int currentXp = data["xp"] ?? 0;
      Map<String, dynamic> activePowerUps = Map<String, dynamic>.from(data["activePowerUps"] ?? {});

      if (currentXp >= cost) {
        DateTime baseTime = DateTime.now();
        if (activePowerUps.containsKey(powerUpId)) {
          Timestamp currentExpiryTs = activePowerUps[powerUpId] as Timestamp;
          DateTime currentExpiry = currentExpiryTs.toDate();
          if (currentExpiry.isAfter(baseTime)) {
            baseTime = currentExpiry;
          }
        }
        
        final expiryDate = baseTime.add(duration);
        activePowerUps[powerUpId] = Timestamp.fromDate(expiryDate);

        transaction.update(docRef, {
          "xp": currentXp - cost,
          "activePowerUps": activePowerUps,
        });
      }
    });
  }
}