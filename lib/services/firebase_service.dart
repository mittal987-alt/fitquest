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
import '../models/anomaly_model.dart';
import '../models/activity_model.dart';

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
    if (level < 15) return "PLAYER";
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
      fitnessGoal: "maintenance",
      strength: 10,
      agility: 10,
      endurance: 10,
      currentStamina: 100,
      maxStamina: 100,
      energyBoostRaidMultiplier: 1.0,
      energyBoostXpMultiplier: 1.0,
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
  // FITNESS & ACTIVITY LOGIC
  // =========================

  /// Updates the player's personal fitness profile using the ML-driven adaptive engine
  Future<void> updateFitnessProfile({
    required String uid,
    required double heightCm,
    required double weightKg,
    required String fitnessGoal,
  }) async {
    double heightM = heightCm / 100;
    double bmi = weightKg / (heightM * heightM);

    // Invoke ML Recommendation Engine (Heuristic)
    final plan = ActivityModel.fromBmiAndGoal(bmi, fitnessGoal);

    await firestore.collection("players").doc(uid).update({
      "heightCm": heightCm,
      "weightKg": weightKg,
      "fitnessGoal": fitnessGoal,
      "fitnessTier": plan.tier,
      "restInterval": plan.restIntervalSeconds,
      "energyBoostXpMultiplier": plan.xpMultiplier,
      "energyBoostRaidMultiplier": plan.raidDamageMultiplier,
      "lastUpdated": FieldValue.serverTimestamp(),
    });
    debugPrint("ML FITNESS PROFILE UPDATED: ${plan.tier} | Goal: $fitnessGoal");
  }

  /// Logs the workout, applies XP bonus based on tier, and activates the energy boost buff
  Future<void> logWorkoutAndEnergyBoost({
    required String uid,
    required int durationMinutes,
    required String tier,
    required double xpMultiplier,
    required double raidMultiplier,
    required List<String> exercises,
  }) async {
    final playerRef = firestore.collection("players").doc(uid);

    int bonusXp = (durationMinutes * 10 * xpMultiplier).toInt(); // 10 XP per minute base scaled by tier multiplier

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(playerRef);
      if (!snap.exists) return;

      final player = PlayerModel.fromMap(snap.data()!);
      String todayKey = DateTime.now().toIso8601String().split('T')[0];

      // Update XP, Log Activity, and set the 60-minute Energy Boost buff
      final now = DateTime.now();
      transaction.update(playerRef, {
        "xp": FieldValue.increment(bonusXp),
        "energyBoostRaidMultiplier": raidMultiplier,
        "energyBoostXpMultiplier": xpMultiplier,
        "lastActivityTimestamp": FieldValue.serverTimestamp(),
        "activePowerUps.energy_boost": Timestamp.fromDate(
            now.add(const Duration(minutes: 60))
        ),
        "dailyHistory.$todayKey.xpGained": FieldValue.increment(bonusXp),
        "dailyHistory.$todayKey.achievements": FieldValue.arrayUnion([
          "WORKOUT: $tier ($durationMinutes min)",
          if (player.bmi != null) "BMI AT SESSION: ${player.bmi!.toStringAsFixed(1)}",
          "DRILLS COMPLETED: ${exercises.join(', ')}"
        ]),
      });
    });

    debugPrint("WORKOUT LOGGED: +$bonusXp XP (Mult: ${xpMultiplier}x). Drills: $exercises. Energy Boost Active.");
  }
  Future<void> ensurePlayerProfileExists(String uid, String email, String name) async {
    final playerRef = firestore.collection("players").doc(uid);
    final snapshot = await playerRef.get();

    if (!snapshot.exists) {
      // This creates the default document structure if it's missing
      await createPlayer(uid: uid, name: name, email: email);
      debugPrint("NEW PLAYER PROFILE CREATED FOR: $uid");
    }
  }

  /// Checks if the user is currently under the 60-minute Energy Boost buff
  Future<bool> isEnergyBoostActive(String uid) async {
    final snap = await firestore.collection("players").doc(uid).get();
    if (!snap.exists) return false;

    final data = snap.data() as Map<String, dynamic>;
    final powerUps = data["activePowerUps"] as Map<String, dynamic>? ?? {};
    final expiry = powerUps["energy_boost"] as Timestamp?;

    if (expiry == null) return false;
    return expiry.toDate().isAfter(DateTime.now());
  }

  // =========================
  // END FITNESS & ACTIVITY LOGIC
  // =========================

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
        "dailyHistory.${DateTime.now().toIso8601String().split('T')[0]}.steps": FieldValue.increment(finalSteps),
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
      if (!snapshot.exists) return false;

      final data = snapshot.data();
      if (data == null) return false;
      final player = PlayerModel.fromMap(data);
      int currentXp = player.xp;
      int currentLevel = player.level;

      // Apply Gear XP Multiplier
      double gearMult = player.getModifier('xp_mult', allGear);
      int finalXpToAdd = (xpToAdd * gearMult).round();

      // Apply XP Booster if active
      if (player.activePowerUps.containsKey("boost")) {
        DateTime expiry = player.activePowerUps["boost"]!;
        if (expiry.isAfter(DateTime.now())) {
          finalXpToAdd = (finalXpToAdd * 2);
        }
      }

      // Apply Energy Boost if active
      if (player.activePowerUps.containsKey("energy_boost")) {
        DateTime expiry = player.activePowerUps["energy_boost"]!;
        if (expiry.isAfter(DateTime.now())) {
          finalXpToAdd = (finalXpToAdd * player.energyBoostXpMultiplier).round();
        }
      }

      // BROADCAST XP GAIN FOR TEAM
      if (player.isInTeam && player.teamId != null) {
        transaction.set(
          firestore.collection("teams").doc(player.teamId).collection("events").doc(),
          {
            "type": "XP_CONTRIBUTION",
            "playerName": player.name,
            "amount": finalXpToAdd,
            "timestamp": FieldValue.serverTimestamp(),
          }
        );
      }

      int newXp = currentXp + finalXpToAdd;
      int newLevel = (newXp ~/ 1000) + 1;

      // Update daily history XP tracking
      String todayKey = DateTime.now().toIso8601String().split('T')[0];
      
      Map<String, dynamic> updates = {
        "xp": newXp,
        "dailyHistory.$todayKey.xpGained": FieldValue.increment(finalXpToAdd),
      };
      
      if (newLevel > currentLevel) {
        updates["level"] = newLevel;
        // Optionally log level up in achievements for that day
        updates["dailyHistory.$todayKey.achievements"] = FieldValue.arrayUnion(["LEVEL UP: $newLevel"]);
      }

      transaction.update(docRef, updates);
      debugPrint("XP INCREMENTED: $xpToAdd (Final: $finalXpToAdd) -> New XP: $newXp, Level: $newLevel");
      return true; // Added return for transaction
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
        // Archive yesterday's data into dailyHistory
        String yesterdayKey = lastDate.toIso8601String().split('T')[0];
        Map<String, dynamic> historyNode = {
          "steps": data["dailySteps"] ?? 0,
          "xpGained": 0, // In a real app, we'd track this throughout the day
          "achievements": [], // Logic for daily achievement badges
          "timestamp": Timestamp.fromDate(lastDate),
        };

        Map<String, dynamic> updates = {
          "lastActiveDate": Timestamp.fromDate(today),
          "claimedQuests": [],
          "dailySteps": 0,
          "dailyHistory.$yesterdayKey": historyNode,
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
  Future<void> claimQuestReward(String uid, String questId, int rewardXp) async {
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

        String todayKey = DateTime.now().toIso8601String().split('T')[0];

        Map<String, dynamic> updates = {
          "claimedQuests": claimed,
          "xp": newXp,
          "dailyHistory.$todayKey.achievements": FieldValue.arrayUnion(["QUEST COMPLETED: $questId"]),
          "dailyHistory.$todayKey.xpGained": FieldValue.increment(rewardXp),
        };

        if (newLevel > currentLevel) {
          updates["level"] = newLevel;
          updates["dailyHistory.$todayKey.achievements"] = FieldValue.arrayUnion(["LEVEL UP: $newLevel"]);
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
  // LEADERBOARDS
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

  Stream<List<PlayerModel>> getSoloLeaderboard() {
    return firestore
        .collection("players")
        .orderBy("totalSteps", descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PlayerModel.fromMap(doc.data())).toList();
    });
  }

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

  Stream<List<TeamModel>> getTeamLeaderboardGlobal() {
    return firestore
        .collection("teams")
        .orderBy("totalSteps", descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TeamModel.fromMap(doc.data())).toList();
    });
  }

  // =========================
  // TEAM OPERATIONS
  // =========================
  Stream<List<TeamModel>> getTeams() {
    return firestore.collection("teams").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TeamModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> deleteTeam(String teamId) async {
    // 1. Reset all members
    var members = await firestore.collection("players").where("teamId", isEqualTo: teamId).get();
    var batch = firestore.batch();
    for (var doc in members.docs) {
      batch.update(doc.reference, {
        "team": "No Team",
        "teamId": null,
        "isInTeam": false,
        "lastTeamAction": FieldValue.serverTimestamp(),
      });
    }

    // 2. Delete team requests
    var requests = await firestore.collection("team_requests").where("teamId", isEqualTo: teamId).get();
    for (var doc in requests.docs) {
      batch.delete(doc.reference);
    }

    // 3. Delete team document
    batch.delete(firestore.collection("teams").doc(teamId));

    await batch.commit();
  }

  Future<void> createTeam(TeamModel team) async {
    await firestore.collection("teams").doc(team.id).set(team.toMap());

    await firestore.collection("players").doc(team.leaderId).update({
      "team": team.name,
      "teamId": team.id,
      "isInTeam": true,
      "lastTeamAction": FieldValue.serverTimestamp(),
    });
  }

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
  // TEAM REQUESTS
  // =========================
  Future<void> sendJoinRequest(TeamRequestModel request) async {
    await firestore.collection("team_requests").doc(request.requestId).set(request.toMap());
  }

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

  Future<void> rejectRequest(String requestId) async {
    await firestore.collection("team_requests").doc(requestId).update({
      "status": "rejected",
    });
  }

  // =========================
  // HEX TILES
  // =========================
  Future<void> saveHexTile(HexTileModel tile) async {
    try {
      await firestore.collection("hex_tiles").doc(tile.tileId).set(tile.toMap());
    } catch (e) {
      debugPrint("FIREBASE ERROR = $e");
    }
  }

  Stream<List<HexTileModel>> getHexTiles() {
    return firestore.collection("hex_tiles").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => HexTileModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> deleteHexTile(String tileId) async {
    await firestore.collection("hex_tiles").doc(tileId).delete();
  }

  // =========================
  // RPG MECHANICS
  // =========================
  Future<void> updateBiometrics({
    required String uid,
    required double heightCm,
    required double weightKg,
    required String fitnessGoal,
    required int stepTarget,
    required int exerciseTarget,
  }) async {
    double meters = heightCm / 100;
    double bmi = weightKg / (meters * meters);

    // RPG Stats Scaling based on BMI
    int strength = 10;
    int agility = 10;
    int endurance = 10;
    int maxStamina = 100;

    if (bmi < 18.5) {
      strength = 8; agility = 14; endurance = 10; maxStamina = 90;
    } else if (bmi < 25.0) {
      strength = 12; agility = 15; endurance = 12; maxStamina = 110;
    } else if (bmi < 30.0) {
      strength = 16; agility = 9; endurance = 14; maxStamina = 130;
    } else {
      strength = 20; agility = 6; endurance = 11; maxStamina = 140;
    }

    // Sync with ML Adaptive Engine
    await updateFitnessProfile(
      uid: uid,
      heightCm: heightCm,
      weightKg: weightKg,
      fitnessGoal: fitnessGoal,
    );

    await firestore.collection("players").doc(uid).update({
      "dailyStepTarget": stepTarget,
      "dailyExerciseTargetMinutes": exerciseTarget,
      "strength": strength,
      "agility": agility,
      "endurance": endurance,
      "maxStamina": maxStamina,
      "currentStamina": maxStamina,
    });
  }

  Future<void> setCharacterClass(String uid, String className) async {
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
  }

  Future<bool> consumeStamina(String uid, int amount) async {
    final docRef = firestore.collection("players").doc(uid);
    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return false;

      int current = snapshot.data()?["currentStamina"] ?? 0;
      if (current < amount) return false;

      transaction.update(docRef, {"currentStamina": current - amount});
      return true;
    });
  }

  Future<void> regenerateStamina(String uid) async {
    final docRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final player = PlayerModel.fromMap(snapshot.data()!);

      if (player.currentStamina < player.maxStamina) {
        int effectiveEndurance = player.effectiveEndurance;
        int regenAmount = (player.maxStamina * 0.01 + effectiveEndurance / 5).ceil();
        transaction.update(docRef, {
          "currentStamina": (player.currentStamina + regenAmount).clamp(0, player.maxStamina)
        });
      }
    });
  }

  // =========================
  // RAIDS
  // =========================
  Future<void> initializeRaid(String teamId, double bossHealth) async {
    await firestore.collection("teams").doc(teamId).update({
      "raidBossHp": bossHealth,
      "raidExpiry": Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
    });
  }

  Future<bool> executeTeamRaidAttack(String uid, String teamId) async {
    final playerRef = firestore.collection("players").doc(uid);
    final teamRef = firestore.collection("teams").doc(teamId);

    return firestore.runTransaction((transaction) async {
      final playerSnap = await transaction.get(playerRef);
      final teamSnap = await transaction.get(teamRef);

      if (!playerSnap.exists || !teamSnap.exists) return false;

      final player = PlayerModel.fromMap(playerSnap.data()!);

      // Check for a specific 'lastRaidAttack' field if it exists in data but not in model yet
      final rawLastAttack = (playerSnap.data()?["lastRaidAttack"] as Timestamp?)?.toDate();
      
      if (rawLastAttack != null && DateTime.now().difference(rawLastAttack).inMinutes < 5) {
        return false;
      }

      int staminaCost = 50;
      if (player.currentStamina < staminaCost) return false;

      double baseDmg = (player.effectiveStrength + player.effectiveAgility).toDouble();
      double gearMult = player.getModifier('raid_dmg_mult', allGear);
      double strongholdBonus = (teamSnap.data()?["strongholdActive"] == true) ? 1.5 : 1.0;
      
      // ENERGY BOOST BONUS
      double energyBoostMult = 1.0;
      if (player.activePowerUps.containsKey("energy_boost")) {
        DateTime expiry = player.activePowerUps["energy_boost"]!;
        if (expiry.isAfter(DateTime.now())) {
          energyBoostMult = player.energyBoostRaidMultiplier;
        }
      }

      double totalDmg = baseDmg * gearMult * strongholdBonus * energyBoostMult;

      transaction.update(playerRef, {
        "currentStamina": player.currentStamina - staminaCost,
        "lastRaidAttack": FieldValue.serverTimestamp(),
        "lastTeamAction": FieldValue.serverTimestamp(),
        "totalRaidDamage": FieldValue.increment(totalDmg.toInt()),
      });

      double currentBossHp = (teamSnap.data()?["raidBossHp"] ?? 100000.0).toDouble();
      double newBossHp = (currentBossHp - totalDmg).clamp(0.0, 1000000.0);
      
      transaction.update(teamRef, {
        "raidBossHp": newBossHp,
        "totalRaidDamage": FieldValue.increment(totalDmg),
      });

      // Log Damage Contribution for FCM Trigger
      transaction.set(
        firestore.collection("teams").doc(teamId).collection("events").doc(),
        {
          "type": "RAID_DAMAGE",
          "playerName": player.name,
          "damage": totalDmg,
          "timestamp": FieldValue.serverTimestamp(),
        }
      );

      // RAID DEFEATED LOGIC
      if (newBossHp <= 0) {
        transaction.set(
          firestore.collection("teams").doc(teamId).collection("events").doc("raid_victory"),
          {
            "type": "RAID_COMPLETED",
            "victor": player.name,
            "timestamp": FieldValue.serverTimestamp(),
          }
        );
        // Distribute Team Rewards (Placeholder for scalable distribution)
        transaction.update(teamRef, {
          "raidActive": false,
          "lastVictory": FieldValue.serverTimestamp(),
        });
      }

      return true;
    });
  }

  Future<void> contributeRaidDamage(String teamId, double damage) async {
    final teamRef = firestore.collection("teams").doc(teamId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(teamRef);
      if (!snapshot.exists) return;

      double currentHp = (snapshot.data()?["raidBossHp"] ?? 100000.0).toDouble();
      double newHp = (currentHp - damage).clamp(0.0, 1000000.0);
      transaction.update(teamRef, {
        "raidBossHp": newHp,
      });

      // Periodic HP Sync log for broadcast
      if (newHp % 500 < damage || newHp <= 0) {
         transaction.set(
          firestore.collection("teams").doc(teamId).collection("events").doc(newHp <= 0 ? "raid_victory" : "hp_sync"),
          {
            "type": newHp <= 0 ? "RAID_COMPLETED" : "BOSS_HP_SYNC",
            "hp": newHp,
            "timestamp": FieldValue.serverTimestamp(),
          }
        );
      }

      if (newHp <= 0) {
        transaction.update(teamRef, {
          "raidActive": false,
          "lastVictory": FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // =========================
  // CRAFTING & INVENTORY
  // =========================
  Future<void> addInventoryItem(String uid, String materialId, int count) async {
    final docRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      Map<String, int> inventory = Map<String, int>.from(snapshot.data()?["inventory"] ?? {});
      inventory[materialId] = (inventory[materialId] ?? 0) + count;

      transaction.update(docRef, {"inventory": inventory});
    });
  }

  Future<bool> craftGear(String uid, String gearId, Map<String, int> recipe) async {
    final docRef = firestore.collection("players").doc(uid);
    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      Map<String, int> inv = Map<String, int>.from(snapshot.data()?["inventory"] ?? {});

      for (var entry in recipe.entries) {
        if ((inv[entry.key] ?? 0) < entry.value) return false;
      }

      for (var entry in recipe.entries) {
        inv[entry.key] = inv[entry.key]! - entry.value;
      }

      transaction.update(docRef, {
        "inventory": inv,
        "ownedGear": FieldValue.arrayUnion([gearId])
      });
      return true;
    });
  }

  // =========================
  // POWER-UPS & GEAR
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

      int currentCurrency = snapshot.data()?["currency"] ?? 0;
      Map<String, dynamic> activePowerUps = Map<String, dynamic>.from(snapshot.data()?["activePowerUps"] ?? {});

      if (currentCurrency >= cost) {
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
          "currency": currentCurrency - cost,
          "activePowerUps": activePowerUps,
        });
      }
    });
  }

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

      int currentCurrency = snap.data()?["currency"] ?? 0;
      List<String> owned = List<String>.from(snap.data()?["ownedGear"] ?? []);

      if (currentCurrency >= gear.price && !owned.contains(gear.id)) {
        owned.add(gear.id);
        transaction.update(docRef, {
          "currency": currentCurrency - gear.price,
          "ownedGear": owned,
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

  Future<void> updateTeamLand({
    required String teamId,
    required int totalLand,
  }) async {
    await firestore.collection("teams").doc(teamId).update({
      "totalLand": totalLand,
    });
  }

  Future<void> updateTeamSteps({
    required String teamId,
    required int stepsToAdd,
  }) async {
    await firestore.collection("teams").doc(teamId).update({
      "totalSteps": FieldValue.increment(stepsToAdd),
    });
  }

  // =========================
  // BOUNTIES & EVENTS
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

      String todayKey = DateTime.now().toIso8601String().split('T')[0];
      transaction.delete(bountyRef);
      transaction.update(playerRef, {
        "xp": FieldValue.increment(bounty.xpReward),
        "dailyHistory.$todayKey.xpGained": FieldValue.increment(bounty.xpReward),
        "dailyHistory.$todayKey.achievements": FieldValue.arrayUnion(["BOUNTY CLAIMED: ${bounty.title}"]),
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

  Stream<List<AnomalyModel>> getAnomalies() {
    return firestore.collection("anomalies").snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AnomalyModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> claimAnomaly(String uid, AnomalyModel anomaly) async {
    final playerRef = firestore.collection("players").doc(uid);
    final anomalyRef = firestore.collection("anomalies").doc(anomaly.id);

    await firestore.runTransaction((transaction) async {
      final pSnap = await transaction.get(playerRef);
      if (!pSnap.exists) return;

      String todayKey = DateTime.now().toIso8601String().split('T')[0];
      transaction.delete(anomalyRef);

      Map<String, int> inventory = Map<String, int>.from(pSnap.data()?["inventory"] ?? {});
      int xpToAdd = anomaly.rewards["XP"] ?? 0;

      anomaly.rewards.forEach((key, value) {
        if (key != "XP") {
          inventory[key] = (inventory[key] ?? 0) + value;
        }
      });

      transaction.update(playerRef, {
        "xp": FieldValue.increment(xpToAdd),
        "inventory": inventory,
        "dailyHistory.$todayKey.xpGained": FieldValue.increment(xpToAdd),
        "dailyHistory.$todayKey.achievements": FieldValue.arrayUnion(["ANOMALY SECURED: ${anomaly.type}"]),
      });
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

  Future<void> updateCurrency(String uid, int amount) async {
    await firestore.collection("players").doc(uid).update({
      "currency": FieldValue.increment(amount),
    });
    debugPrint("CURRENCY UPDATED FOR $uid: +$amount");
  }

  // =========================
  // MOVEMENT & STEPS
  // =========================
  Future<void> sendTacticalPing(String teamId, String sectorTileId, String message) async {
    await firestore.collection("teams").doc(teamId).collection("pings").add({
      "sector": sectorTileId,
      "message": message,
      "timestamp": FieldValue.serverTimestamp(),
      "senderId": auth.currentUser?.uid,
    });
  }

  Future<void> logHourlyActivity(String uid, int steps) async {
    String hourKey = DateTime.now().hour.toString();
    final docRef = firestore.collection("players").doc(uid);
    await docRef.update({
      "hourlySteps.$hourKey": FieldValue.increment(steps),
    });
  }

  Future<void> processSectorCapture(String uid, String teamId, String tileId) async {
    final teamRef = firestore.collection("teams").doc(teamId);
    await firestore.runTransaction((transaction) async {
      final teamSnap = await transaction.get(teamRef);
      List<dynamic> clusters = List.from(teamSnap.data()?["strongholdClusters"] ?? []);

      if (clusters.length >= 4) {
        transaction.update(teamRef, {
          "strongholdActive": true,
        });
      }

      transaction.update(teamRef, {
        "strongholdClusters": FieldValue.arrayUnion([tileId])
      });
    });

    await sendTacticalPing(teamId, tileId, "Sector secured! Stronghold expansion in progress.");
  }
}
