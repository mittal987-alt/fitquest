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
  // FITNESS & ACTIVITY LOGIC
  // =========================

  /// Initializes or updates the player's personal fitness plan based on weight
  Future<void> updateUserFitnessPlan(String uid, double currentWeight) async {
    final plan = ActivityModel.fromWeight(currentWeight);

    await firestore.collection("players").doc(uid).update({
      "fitnessTier": plan.tier,
      "restInterval": plan.restIntervalSeconds,
      "xpMultiplier": plan.xpMultiplier,
      "lastUpdated": FieldValue.serverTimestamp(),
    });
    debugPrint("FITNESS PLAN UPDATED: ${plan.tier}");
  }

  /// Logs the workout, applies XP bonus based on tier, and activates the recharge buff
  Future<void> logWorkoutAndRecharge(String uid, int durationMinutes, String tier) async {
    final playerRef = firestore.collection("players").doc(uid);

    // Determine multiplier based on Tier logic
    double multiplier = (tier == "ELITE") ? 2.0 : (tier == "ACTIVE" ? 1.5 : 1.0);
    int bonusXp = (durationMinutes * 10 * multiplier).toInt(); // 10 XP per minute base

    await firestore.runTransaction((transaction) async {
      final snap = await transaction.get(playerRef);
      if (!snap.exists) return;

      // Update XP, Log Activity, and set the 60-minute Metabolic Recharge buff
      transaction.update(playerRef, {
        "xp": FieldValue.increment(bonusXp),
        "lastActivityTimestamp": FieldValue.serverTimestamp(),
        "activePowerUps.metabolic_recharge": Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 60))
        ),
      });
    });

    debugPrint("WORKOUT LOGGED: +$bonusXp XP. Metabolic Recharge Active.");
  }

  /// Checks if the user is currently under the 60-minute Metabolic Recharge buff
  Future<bool> isRechargeActive(String uid) async {
    final snap = await firestore.collection("players").doc(uid).get();
    if (!snap.exists) return false;

    final data = snap.data() as Map<String, dynamic>;
    final powerUps = data["activePowerUps"] as Map<String, dynamic>? ?? {};
    final expiry = powerUps["metabolic_recharge"] as Timestamp?;

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

      // Apply Metabolic Recharge if active
      if (player.activePowerUps.containsKey("metabolic_recharge")) {
        DateTime expiry = player.activePowerUps["metabolic_recharge"]!;
        if (expiry.isAfter(DateTime.now())) {
          // Tier-based multiplier is pre-applied in activity_screen completion, 
          // or we can apply it globally here if preferred. 
          // For now, consistent with ActivityModel.
          finalXpToAdd = (finalXpToAdd * 1.5).round();
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
    required int stepTarget,
    required int exerciseTarget,
  }) async {
    double meters = heightCm / 100;
    double bmi = weightKg / (meters * meters);

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

    await firestore.collection("players").doc(uid).update({
      "heightCm": heightCm,
      "weightKg": weightKg,
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
      double totalDmg = baseDmg * gearMult * strongholdBonus;

      transaction.update(playerRef, {
        "currentStamina": player.currentStamina - staminaCost,
        "lastRaidAttack": FieldValue.serverTimestamp(),
        "lastTeamAction": FieldValue.serverTimestamp(),
      });

      double currentBossHp = (teamSnap.data()?["raidBossHp"] ?? 100000.0).toDouble();
      transaction.update(teamRef, {"raidBossHp": (currentBossHp - totalDmg).clamp(0.0, 1000000.0)});

      return true;
    });
  }

  Future<void> contributeRaidDamage(String teamId, double damage) async {
    final teamRef = firestore.collection("teams").doc(teamId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(teamRef);
      if (!snapshot.exists) return;

      double currentHp = (snapshot.data()?["raidBossHp"] ?? 100000.0).toDouble();
      transaction.update(teamRef, {
        "raidBossHp": (currentHp - damage).clamp(0.0, 1000000.0),
      });
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

      int currentXp = snapshot.data()?["xp"] ?? 0;
      Map<String, dynamic> activePowerUps = Map<String, dynamic>.from(snapshot.data()?["activePowerUps"] ?? {});

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

  // =========================
  // TACTICAL PINGS & TELEMETRY
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
      "hourlyTelemetry.$hourKey": FieldValue.increment(steps),
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
