import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../models/hex_tile_model.dart';
import '../models/team_request_model.dart';
import '../models/global_event_model.dart';
import '../models/gear_model.dart';
import '../models/bounty_model.dart';

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
      final docRef = firestore.collection("players").doc(uid);
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      final player = PlayerModel.fromMap(snapshot.data()!);
      double stepMult = player.getModifier('step_mult', allGear);
      int finalSteps = (stepsToAdd * stepMult).round();

      await docRef.update({
        "totalSteps": FieldValue.increment(finalSteps),
        "dailySteps": FieldValue.increment(finalSteps),
      });
      debugPrint("STEPS UPDATED => +$finalSteps (Mult: $stepMult)");
    } catch (e) {
      debugPrint("STEP UPDATE ERROR => $e");
    }
  }

  // =========================
  // UPDATE HARDWARE BASELINE
  // =========================
  Future<void> updateLastHardwareSteps({
    required String uid,
    required int hardwareSteps,
  }) async {
    try {
      await firestore.collection("players").doc(uid).update({
        "lastHardwareStepCount": hardwareSteps,
      });
      debugPrint("HARDWARE BASELINE UPDATED => $hardwareSteps");
    } catch (e) {
      debugPrint("HARDWARE BASELINE UPDATE ERROR => $e");
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

      // Apply Gear XP Multiplier
      double gearMult = PlayerModel.fromMap(data).getModifier('xp_mult', allGear);
      int finalXpToAdd = (xpToAdd * gearMult).round();

      // Apply XP Booster if active
      Map<String, dynamic> activePowerUps = Map<String, dynamic>.from(data["activePowerUps"] ?? {});
      if (activePowerUps.containsKey("boost")) {
        Timestamp expiry = activePowerUps["boost"] as Timestamp;
        if (expiry.toDate().isAfter(DateTime.now())) {
          finalXpToAdd = (finalXpToAdd * 2);
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
  // UPLOAD AVATAR FILE
  // =========================
  Future<String?> uploadAvatarFile(String uid, Uint8List fileBytes) async {
    try {
      final storageInstance = FirebaseStorage.instanceFor(
        bucket: "gs://territory-game-462f9.firebasestorage.app",
      );

      final ref = storageInstance.ref().child("avatars").child("$uid.jpg");

      UploadTask uploadTask = ref.putData(
        fileBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        final url = await ref.getDownloadURL();
        debugPrint("UPLOAD SUCCESS: $url");
        return url;
      } else {
        debugPrint("UPLOAD FAILED: State is ${snapshot.state}");
        return null;
      }
    } catch (e) {
      debugPrint("UPLOAD ERROR TYPE: ${e.runtimeType}");
      debugPrint("UPLOAD ERROR: $e");
      return null;
    }
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
    int currentMembers = teamDoc["members"] ?? 0;
    await firestore.collection("teams").doc(teamId).update({
      "members": currentMembers + 1,
    });
  }

  // =========================
  // REJECT REQUEST
  // =========================
  Future<void> rejectRequest(String requestId) async {
    await firestore.collection("team_requests").doc(requestId).update({
      "status": "rejected",
    });
  }

  // =========================
  // LEAVE / KICK
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

    int currentMembers = teamDoc["members"] ?? 0;
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
      "teamId": null,
      "isInTeam": false,
      "lastTeamAction": FieldValue.serverTimestamp(),
    });

    DocumentSnapshot teamDoc = await firestore.collection("teams").doc(teamId).get();
    int currentMembers = teamDoc["members"] ?? 0;
    if (currentMembers > 0) {
      await firestore.collection("teams").doc(teamId).update({
        "members": currentMembers - 1,
      });
    }
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

  // =========================
  // GLOBAL EVENTS
  // =========================
  Stream<GlobalEventModel?> getActiveGlobalEvent() {
    return firestore
        .collection("global_events")
        .where("isActive", isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return GlobalEventModel.fromMap(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    });
  }

  Future<void> contributeToGlobalEvent(int steps) async {
    final query = await firestore
        .collection("global_events")
        .where("isActive", isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final docRef = query.docs.first.reference;
      await docRef.update({
        "currentSteps": FieldValue.increment(steps),
      });
    }
  }

  // =========================
  // BOUNTIES
  // =========================
  Stream<List<BountyModel>> getActiveBounties() {
    return firestore
        .collection("bounties")
        .where("expiresAt", isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BountyModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> claimBounty(String uid, BountyModel bounty) async {
    final playerRef = firestore.collection("players").doc(uid);
    final bountyRef = firestore.collection("bounties").doc(bounty.id);

    await firestore.runTransaction((transaction) async {
      final pSnap = await transaction.get(playerRef);
      if (!pSnap.exists) return;

      transaction.delete(bountyRef);
      transaction.update(playerRef, {
        "xp": FieldValue.increment(bounty.xpReward),
      });

      if (bounty.itemReward != null) {
        List<String> owned = List<String>.from(pSnap.data()?["ownedGear"] ?? []);
        if (!owned.contains(bounty.itemReward)) {
          owned.add(bounty.itemReward!);
          transaction.update(playerRef, {"ownedGear": owned});
        }
      }
    });
  }

  // =========================
  // GEAR & ARMORY
  // =========================
  Stream<List<GearModel>> getGear() {
    return firestore.collection("gear").snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return allGear;
      return snapshot.docs.map((doc) => GearModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> purchaseGear(String uid, GearModel gear) async {
    final docRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;

      int currentXp = snap.data()?["xp"] ?? 0;
      List<String> owned = List<String>.from(snap.data()?["ownedGear"] ?? []);

      if (currentXp >= gear.price && !owned.contains(gear.id)) {
        owned.add(gear.id);
        transaction.update(docRef, {
          "xp": currentXp - gear.price,
          "ownedGear": owned,
        });
      }
    });
  }
  // Append to your existing methods in FirebaseService:
  Future<void> updateBiometrics({
    required String uid,
    required double heightCm,
    required double weightKg,
    required int stepTarget,
    required int exerciseTarget,
  }) async {
    try {
      double meters = heightCm / 100;
      double bmi = weightKg / (meters * meters);

      // RPG Character Stat Distribution Algorithm
      int strength = 10;
      int agility = 10;
      int endurance = 10;
      int maxStamina = 100;

      if (bmi < 18.5) {
        strength = 8;   agility = 14;  endurance = 10; maxStamina = 90;
      } else if (bmi < 25.0) {
        strength = 12;  agility = 15;  endurance = 12; maxStamina = 110;
      } else if (bmi < 30.0) {
        strength = 16;  agility = 9;   endurance = 14; maxStamina = 130;
      } else {
        strength = 20;  agility = 6;   endurance = 11; maxStamina = 140;
      }

      await firestore.collection("players").doc(uid).update({
        "heightCm": heightCm,
        "weightKg": weightKg,
        "dailyStepTarget": stepTarget,
        "dailyExerciseTargetMinutes": exerciseTarget,
        "strength": strength,
        "agility": agility,
        "endurance": endurance,
        "maxStamina": maxStamina,
        "currentStamina": maxStamina, // Instantly refresh energy tank on calibration
      });
    } catch (e) {
      debugPrint("DATABASE ERROR UPDATING TELEMETRY BIOMETRICS: $e");
      rethrow;
    }
  }

  // RPG Class Selection
  Future<void> setCharacterClass(String uid, String className) async {
    try {
      int strBonus = 0;
      int agiBonus = 0;
      int endBonus = 0;

      if (className == 'tank') strBonus = 5;
      if (className == 'scout') agiBonus = 5;
      if (className == 'medic') endBonus = 5;

      final docRef = firestore.collection("players").doc(uid);
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        int currentStr = snapshot.data()?["strength"] ?? 10;
        int currentAgi = snapshot.data()?["agility"] ?? 10;
        int currentEnd = snapshot.data()?["endurance"] ?? 10;

        transaction.update(docRef, {
          "characterClass": className,
          "strength": currentStr + strBonus,
          "agility": currentAgi + agiBonus,
          "endurance": currentEnd + endBonus,
        });
      });
    } catch (e) {
      debugPrint("DATABASE ERROR SETTING CHARACTER CLASS: $e");
      rethrow;
    }
  }

  // Action helper to spend stamina during Hex Captures or Bounties
  Future<bool> consumeStamina(String uid, int amount) async {
    final docRef = firestore.collection("players").doc(uid);

    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return false;

      int current = snapshot.data()?["currentStamina"] ?? 0;
      if (current < amount) return false; // Out of energy!

      transaction.update(docRef, {"currentStamina": current - amount});
      return true;
    });
  }

  Future<void> regenerateStamina(String uid) async {
    final docRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      int current = snapshot.data()?["currentStamina"] ?? 0;
      int max = snapshot.data()?["maxStamina"] ?? 100;
      int endurance = snapshot.data()?["endurance"] ?? 10;

      if (current < max) {
        // Regen rate tied to endurance (1% of max + endurance/5)
        int effectiveEndurance = endurance + PlayerModel.fromMap(snapshot.data()!).getModifier('endurance', allGear).toInt();
        int regenAmount = (max * 0.01 + effectiveEndurance / 5).ceil();
        transaction.update(docRef, {
          "currentStamina": (current + regenAmount).clamp(0, max)
        });
      }
    });
  }

  Future<void> equipGear(String uid, GearModel gear) async {
    final docRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;

      Map<String, String> equipped = Map<String, String>.from(snap.data()?["equippedGear"] ?? {});
      equipped[gear.slot.toString().split('.').last] = gear.id;

      transaction.update(docRef, {"equippedGear": equipped});
    });
  }

  // =========================
  // STRONGHOLDS
  // =========================
  Future<void> checkAndCreateStronghold(String teamId, String centerTileId) async {
    final teamRef = firestore.collection("teams").doc(teamId);
    await teamRef.update({
      "strongholdClusters": FieldValue.arrayUnion([centerTileId]),
    });
  }
}
