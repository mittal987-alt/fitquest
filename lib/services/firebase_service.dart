import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../models/walk_session_model.dart';
import '../models/gear_model.dart';
import '../models/power_up_model.dart';
import '../models/raid_log_model.dart';
import '../models/world_event_model.dart';
import '../models/team_request_model.dart';
import '../config/gameplay_rules.dart';
import '../config/crafting_recipes.dart';

class FirebaseService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  User? get currentUser => auth.currentUser;

  // Boss Pool from GameplayRules
  final List<Map<String, dynamic>> bossPool = GameplayRules.bossPool;

  Stream<PlayerModel?> getPlayerStream(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return firestore.collection("players").doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return PlayerModel.fromMap(snapshot.data()!);
    });
  }

  Future<PlayerModel?> getPlayer(String uid) async {
    final doc = await firestore.collection("players").doc(uid).get();
    if (!doc.exists) return null;
    return PlayerModel.fromMap(doc.data()!);
  }

  Future<void> createPlayer(User user) async {
    final player = PlayerModel(
      uid: user.uid,
      name: user.displayName ?? "New Strider",
      email: user.email ?? "",
      team: "No Team",
      isInTeam: false,
      totalSteps: 0,
      dailySteps: 0,
      lastHardwareStepCount: -1,
      trustScore: 100,
      level: 1,
      xp: 0,
      avatar: "default_avatar",
      totalLand: 0,
    );
    await firestore.collection("players").doc(user.uid).set(player.toMap());
  }

  Future<void> updateSteps(String uid, int steps, double distance, int calories) async {
    await firestore.collection("players").doc(uid).update({
      "dailySteps": FieldValue.increment(steps),
      "totalSteps": FieldValue.increment(steps),
      "dailyDistance": FieldValue.increment(distance),
      "dailyCalories": FieldValue.increment(calories),
      "xp": FieldValue.increment(steps ~/ 10),
    });
  }

  Future<void> incrementXP({required String uid, required int xpToAdd}) async {
    await firestore.collection("players").doc(uid).update({
      "xp": FieldValue.increment(xpToAdd),
    });
  }

  Future<void> updateCurrency(String uid, int amount) async {
    await firestore.collection("players").doc(uid).update({
      "currency": FieldValue.increment(amount),
    });
  }

  Future<void> unlockAchievement(String uid, String achievementId) async {
    await firestore.collection("players").doc(uid).update({
      "unlockedAchievements": FieldValue.arrayUnion([achievementId]),
    });
    
    // Log to activity feed
    await firestore.collection("activity_feed").add({
      "userId": uid,
      "type": "achievement",
      "itemId": achievementId,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveWalkSession(WalkSessionModel session) async {
    await firestore.collection("walk_sessions").add(session.toMap());
    
    // Update player's total land if session has many steps
    if (session.steps > 1000) {
      await firestore.collection("players").doc(session.userId).update({
        "totalLand": FieldValue.increment(1),
      });
    }
  }

  Future<void> sendTacticalPing(String teamId, String channel, String message) async {
    await firestore.collection("teams").doc(teamId).collection("pings").add({
      "channel": channel,
      "message": message,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Stream<List<TeamModel>> getTeams() {
    return firestore.collection("teams").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TeamModel.fromMap(doc.data())).toList();
    });
  }

  /// Authoritative raid attack logic. Handles stamina, gear, and boss state.
  Future<(bool success, bool defeated, bool primalSpirit)> executeTeamRaidAttack(String uid, String teamId) async {
    final playerRef = firestore.collection("players").doc(uid);
    final teamRef = firestore.collection("teams").doc(teamId);

    final result = await firestore.runTransaction((transaction) async {
      final playerSnap = await transaction.get(playerRef);
      final teamSnap = await transaction.get(teamRef);

      if (!playerSnap.exists || !teamSnap.exists) return {"success": false};

      final player = PlayerModel.fromMap(playerSnap.data()!);

      final rawLastAttack = (playerSnap.data()?["lastRaidAttack"] as Timestamp?)?.toDate();
      if (rawLastAttack != null && DateTime.now().difference(rawLastAttack).inMinutes < 5) {
        return {"success": false};
      }

      int staminaCost = 50;
      if (player.currentStamina < staminaCost) return {"success": false};

      double baseDmg = (player.effectiveStrength + player.effectiveAgility).toDouble();
      double gearMult = player.getModifier('raid_dmg_mult', allGear);
      double strongholdBonus = (teamSnap.data()?["strongholdActive"] == true) ? 1.5 : 1.0;

      // ELEMENTAL WEAKNESS LOGIC
      double elementalMult = 1.0;
      final bossId = teamSnap.data()?["raidBossId"] ?? "void_titan";
      final bossConfig = bossPool.firstWhere((b) => b["id"] == bossId, orElse: () => bossPool[0]);
      final weakness = bossConfig["weakness"];

      String playerElement = "Physical";
      if (player.characterClass == 'medic') playerElement = "Light";
      if (player.characterClass == 'tank') playerElement = "Ice";
      if (player.characterClass == 'scout') playerElement = "Earth";

      if (playerElement == weakness) {
        elementalMult = 2.0;
      }

      // ENERGY BOOST BONUS
      double energyBoostMult = 1.0;
      if (player.activePowerUps.containsKey("energy_boost")) {
        DateTime expiry = player.activePowerUps["energy_boost"]!;
        if (expiry.isAfter(DateTime.now())) {
          energyBoostMult = player.energyBoostRaidMultiplier;
        }
      }

      double totalDmg = baseDmg * gearMult * strongholdBonus * energyBoostMult * elementalMult;

      // SYNERGY RESONANCE CALCULATION
      Map<String, DateTime> resonance = Map<String, DateTime>.from(teamSnap.data()?["synergyResonance"] ?? {});
      double synergyMult = 1.0;
      int activeClasses = 0;
      resonance.forEach((className, expiry) {
        if (expiry.isAfter(DateTime.now())) {
          synergyMult += 0.15; // +15% damage per active class resonance
          activeClasses++;
        }
      });

      // PRIMAL SPIRIT ULTIMATE LOGIC
      bool primalSpiritTriggered = false;
      if (activeClasses >= 3) {
        int teamSize = (teamSnap.data()?["members"] as num?)?.toInt() ?? 1;
        double triggerChance = GameplayRules.getBalancedPrimalSpiritTriggerChance(teamSize);
        if (Random().nextDouble() < triggerChance) {
          totalDmg *= GameplayRules.primalSpiritDamageMultiplier;
          primalSpiritTriggered = true;
        }
      }

      totalDmg *= synergyMult;

      // Update resonance for current player class
      if (player.characterClass != null) {
        resonance[player.characterClass!] = DateTime.now().add(const Duration(minutes: 15));
      }

      Map<String, dynamic> resonanceToMap = {};
      resonance.forEach((key, value) => resonanceToMap[key] = Timestamp.fromDate(value));

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
        "synergyResonance": resonanceToMap,
      });

      bool isDefeated = false;
      String bossName = bossConfig["name"];

      if (newBossHp <= 0) {
        isDefeated = true;
        final raidLogRef = teamRef.collection("raid_history").doc();
        transaction.set(raidLogRef, {
          "bossName": bossName,
          "timestamp": FieldValue.serverTimestamp(),
          "totalDamage": (teamSnap.data()?["totalRaidDamage"] ?? 0.0) + totalDmg,
          "victorName": player.name,
          "isSuccess": true,
        });

        // SPAWN NEXT BOSS FROM POOL
        final nextBoss = bossPool[Random().nextInt(bossPool.length)];
        transaction.update(teamRef, {
          "raidBossId": nextBoss["id"],
          "raidBossHp": nextBoss["maxHp"],
          "raidActive": true,
          "totalRaidDamage": 0.0,
          "lastVictory": FieldValue.serverTimestamp(),
        });
      }

      return {
        "success": true,
        "defeated": isDefeated,
        "totalDamage": (teamSnap.data()?["totalRaidDamage"] ?? 0.0) + totalDmg,
        "bossName": bossName,
        "primalSpirit": primalSpiritTriggered
      };
    });

    if (result["success"] == true && result["defeated"] == true) {
      await distributeRaidRewards(
        teamId: teamId,
        totalDamage: result["totalDamage"] as double,
        bossName: result["bossName"] as String
      );
    }

    return (
      result["success"] == true, 
      result["defeated"] == true, 
      result["primalSpirit"] == true
    );
  }

  Future<void> distributeRaidRewards({
    required String teamId,
    required double totalDamage,
    required String bossName,
  }) async {
    try {
      final participantsQuery = await firestore
          .collection("players")
          .where("teamId", isEqualTo: teamId)
          .where("totalRaidDamage", isGreaterThan: 0)
          .get();

      if (participantsQuery.docs.isEmpty) return;

      final batch = firestore.batch();
      final random = Random();
      final todayKey = DateTime.now().toIso8601String().split('T')[0];

      for (var doc in participantsQuery.docs) {
        final data = doc.data();
        final int playerDamage = (data["totalRaidDamage"] as num?)?.toInt() ?? 0;

        double ratio = totalDamage > 0 ? playerDamage / totalDamage : (1.0 / participantsQuery.docs.length);
        ratio = ratio.clamp(0.0, 1.0);

        int xpReward = (1000 * ratio).toInt() + 500;
        int currencyReward = (500 * ratio).toInt() + 250;

        Map<String, int> inventory = Map<String, int>.from(data["inventory"] ?? {});
        List<String> lootTypes = [
          CraftingRecipes.materialSilicon,
          CraftingRecipes.materialEnergyCore,
          CraftingRecipes.materialNanites,
        ];

        int drops = 1;
        if (ratio > 0.3) drops = 2;
        if (ratio > 0.6) drops = 3;

        for (int i = 0; i < drops; i++) {
          String droppedMaterial = lootTypes[random.nextInt(lootTypes.length)];
          inventory[droppedMaterial] = (inventory[droppedMaterial] ?? 0) + 1;
        }

        batch.update(doc.reference, {
          "xp": FieldValue.increment(xpReward),
          "currency": FieldValue.increment(currencyReward),
          "inventory": inventory,
          "totalRaidDamage": 0,
          "dailyHistory.$todayKey.achievements": FieldValue.arrayUnion(["RAID DEFEATED: $bossName"]),
        });
      }

      await batch.commit();
      debugPrint("RAID REWARDS DISTRIBUTED FOR TEAM: $teamId");
    } catch (e) {
      debugPrint("FAILED TO DISTRIBUTE RAID REWARDS: $e");
    }
  }

  Future<bool> craftGear(String uid, String gearId, Map<String, int> recipe) async {
    final docRef = firestore.collection("players").doc(uid);
    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return false;

      Map<String, int> inv = Map<String, int>.from(snapshot.data()?["inventory"] ?? {});
      for (var entry in recipe.entries) {
        if ((inv[entry.key] ?? 0) < entry.value) return false;
      }

      for (var entry in recipe.entries) {
        inv[entry.key] = inv[entry.key]! - entry.value;
      }

      Map<String, dynamic> updates = {"inventory": inv};

      final matchingPowerUps = shopItems.where((p) => p.id == gearId);
      if (matchingPowerUps.isNotEmpty) {
        final powerUp = matchingPowerUps.first;
        Map<String, dynamic> activePowerUps = Map<String, dynamic>.from(snapshot.data()?["activePowerUps"] ?? {});

        DateTime baseTime = DateTime.now();
        if (activePowerUps.containsKey(gearId)) {
          final currentExpiry = (activePowerUps[gearId] as Timestamp).toDate();
          if (currentExpiry.isAfter(baseTime)) baseTime = currentExpiry;
        }
        activePowerUps[gearId] = Timestamp.fromDate(baseTime.add(powerUp.duration));
        updates["activePowerUps"] = activePowerUps;
      } else {
        updates["ownedGear"] = FieldValue.arrayUnion([gearId]);
      }

      transaction.update(docRef, updates);
      return true;
    });
  }

  Stream<List<RaidLog>> getRaidHistory(String teamId) {
    return firestore
        .collection("teams")
        .doc(teamId)
        .collection("raid_history")
        .orderBy("timestamp", descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => RaidLog.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<WorldEventModel>> getWorldEvents() {
    return firestore
        .collection("world_events")
        .where("isActive", isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => WorldEventModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> contributeToWorldEvent(String eventId, String teamId, String uid, {int bonus = 0}) async {
    final playerRef = firestore.collection("players").doc(uid);
    final eventRef = firestore.collection("world_events").doc(eventId);

    await firestore.runTransaction((transaction) async {
      final playerSnap = await transaction.get(playerRef);
      if (!playerSnap.exists) return;

      final player = PlayerModel.fromMap(playerSnap.data()!);
      const int cost = GameplayRules.worldEventContributionCost;

      if (player.currentStamina < cost) return;

      transaction.update(playerRef, {
        "currentStamina": player.currentStamina - cost,
        "xp": FieldValue.increment(25 + (bonus * 10)),
      });

      transaction.update(eventRef, {
        "teamContributions.$teamId": FieldValue.increment(1 + bonus),
      });
    });
  }

  Future<void> regenerateStamina(String uid) async {
    final docRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      int current = snapshot.data()?["currentStamina"] ?? 0;
      int max = snapshot.data()?["maxStamina"] ?? GameplayRules.baseMaxStamina;

      if (current < max) {
        transaction.update(docRef, {
          "currentStamina": (current + GameplayRules.passiveStaminaRegen).clamp(0, max),
        });
      }
    });
  }

  Future<void> setCharacterClass(String uid, String className) async {
    await firestore.collection("players").doc(uid).update({
      "characterClass": className,
    });
  }

  Stream<List<HexTileModel>> getHexTiles() {
    return firestore.collection("hex_tiles").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => HexTileModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> saveHexTile(HexTileModel tile) async {
    await firestore.collection("hex_tiles").doc(tile.tileId).set(tile.toMap());
  }

  Stream<List<BountyModel>> getActiveBounties() {
    return firestore
        .collection("bounties")
        .where("expiresAt", isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BountyModel.fromMap(doc.data())).toList();
    });
  }

  Stream<List<AnomalyModel>> getAnomalies() {
    return firestore.collection("anomalies").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AnomalyModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<GearModel>> getGear() {
    // Gear is currently static in allGear, but for consistency we'll return a stream
    return Stream.value(allGear);
  }

  Future<void> claimBounty(String uid, BountyModel bounty) async {
    final playerRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final playerSnap = await transaction.get(playerRef);
      if (!playerSnap.exists) return;

      Map<String, dynamic> updates = {
        "xp": FieldValue.increment(bounty.xpReward),
      };

      if (bounty.itemReward != null) {
        updates["ownedGear"] = FieldValue.arrayUnion([bounty.itemReward!]);
      }

      transaction.update(playerRef, updates);
      transaction.delete(firestore.collection("bounties").doc(bounty.id));
    });
  }

  Future<void> claimAnomaly(String uid, AnomalyModel anomaly) async {
    final playerRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final playerSnap = await transaction.get(playerRef);
      if (!playerSnap.exists) return;

      Map<String, int> inventory = Map<String, int>.from(playerSnap.data()?["inventory"] ?? {});
      int xpReward = 0;

      anomaly.rewards.forEach((item, count) {
        if (item == "XP") {
          xpReward += count;
        } else {
          inventory[item] = (inventory[item] ?? 0) + count;
        }
      });

      transaction.update(playerRef, {
        "inventory": inventory,
        "xp": FieldValue.increment(xpReward),
      });
      transaction.delete(firestore.collection("anomalies").doc(anomaly.id));
    });
  }

  Future<bool> consumeStamina(String uid, int amount) async {
    final docRef = firestore.collection("players").doc(uid);
    final success = await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return false;
      int current = (snapshot.data()?["currentStamina"] as num?)?.toInt() ?? 0;
      if (current < amount) return false;
      transaction.update(docRef, {
        "currentStamina": current - amount,
      });
      return true;
    });
    return success;
  }

  Future<void> updateLastHardwareSteps(String uid, int steps) async {
    await firestore.collection("players").doc(uid).update({
      "lastHardwareStepCount": steps,
    });
  }

  Future<void> syncTelemetry(String uid, Map<String, int> telemetry) async {
    await firestore.collection("players").doc(uid).update({
      "hourlySteps": telemetry,
      "lastSyncTime": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTeamSteps(String teamId, int steps) async {
    await firestore.collection("teams").doc(teamId).update({
      "totalSteps": FieldValue.increment(steps),
    });
  }

  Future<void> contributeToGlobalEvent(String uid, int steps) async {
    // Logic for global event contribution
  }

  Future<void> checkAndResetDailyStats(String uid) async {
    // Logic to reset daily stats if it's a new day
  }

  Future<void> addInventoryItem(String uid, String item, int count) async {
    final docRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      Map<String, int> inventory = Map<String, int>.from(snapshot.data()?["inventory"] ?? {});
      inventory[item] = (inventory[item] ?? 0) + count;
      transaction.update(docRef, {"inventory": inventory});
    });
  }

  Future<void> updatePlayerName(String uid, String name) async {
    await firestore.collection("players").doc(uid).update({"name": name});
  }

  Future<void> updateTerritoryColor(String uid, String colorHex) async {
    await firestore.collection("players").doc(uid).update({"territoryColor": colorHex});
  }

  Future<void> updateAvatar(String uid, String avatarId) async {
    await firestore.collection("players").doc(uid).update({"avatar": avatarId});
  }

  Future<String> uploadAvatarFile(String uid, dynamic file) async {
    return "uploaded_url";
  }

  Future<List<PlayerModel>> searchPlayers(String query) async {
    final snapshot = await firestore.collection("players").where("name", isGreaterThanOrEqualTo: query).get();
    return snapshot.docs.map((doc) => PlayerModel.fromMap(doc.data())).toList();
  }

  Future<void> addFriend(String uid, String friendUid) async {
    await firestore.collection("players").doc(uid).update({
      "friends": FieldValue.arrayUnion([friendUid])
    });
  }

  Future<void> removeFriend(String uid, String friendUid) async {
    await firestore.collection("players").doc(uid).update({
      "friends": FieldValue.arrayRemover([friendUid])
    });
  }

  Future<void> equipGear(String uid, String slot, String gearId) async {
    final docRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      Map<String, String> equipped = Map<String, String>.from(snapshot.data()?["equippedGear"] ?? {});
      equipped[slot] = gearId;
      transaction.update(docRef, {"equippedGear": equipped});
    });
  }

  Stream<List<PlayerModel>> getLeaderboard() {
    return firestore
        .collection("players")
        .orderBy("totalSteps", descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PlayerModel.fromMap(doc.data())).toList();
    });
  }

  Future<void> kickPlayer({required String playerId, required String teamId}) async {
    await firestore.runTransaction((transaction) async {
      final playerRef = firestore.collection("players").doc(playerId);
      final teamRef = firestore.collection("teams").doc(teamId);

      transaction.update(playerRef, {
        "isInTeam": false,
        "teamId": null,
        "team": "No Team",
      });

      transaction.update(teamRef, {
        "members": FieldValue.increment(-1),
      });
    });
  }

  Future<void> claimQuestReward(String uid, String questId, int xpReward) async {
    final docRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      List<String> claimed = List<String>.from(snapshot.data()?["claimedQuests"] ?? []);
      if (claimed.contains(questId)) return;

      transaction.update(docRef, {
        "claimedQuests": FieldValue.arrayUnion([questId]),
        "xp": FieldValue.increment(xpReward),
      });
    });
  }
}
