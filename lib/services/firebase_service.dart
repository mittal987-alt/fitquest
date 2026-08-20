import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../models/walk_session_model.dart';
import '../models/gear_model.dart';
import '../models/power_up_model.dart';
import '../models/raid_log_model.dart';
import '../models/world_event_model.dart';
import '../models/hex_tile_model.dart';
import '../models/bounty_model.dart';
import '../models/anomaly_model.dart';
import '../models/team_request_model.dart';
import '../models/chat_message_model.dart';
import '../models/activity_feed_model.dart';
import '../models/team_challenge_model.dart';
import '../config/gameplay_rules.dart';
import '../config/crafting_recipes.dart';

class FirebaseService {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseStorage storage;

  FirebaseService({FirebaseFirestore? firestore, FirebaseAuth? auth, FirebaseStorage? storage})
      : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance,
        storage = storage ?? FirebaseStorage.instance;

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

  Future<void> createPlayer({required String uid, required String name, required String email}) async {
    final player = PlayerModel(
      uid: uid,
      name: name,
      email: email,
      team: "No Team",
      isInTeam: false,
      totalSteps: 0,
      dailySteps: 0,
      lastHardwareStepCount: -1,
      trustScore: 100,
      level: 1,
      xp: 0,
      avatar: "",
      totalLand: 0,
    );
    await firestore.collection("players").doc(uid).set(player.toMap());
  }

  Future<void> updateSteps(String uid, int steps, double distance, int calories) async {
    await firestore.collection("players").doc(uid).update({
      "dailySteps": FieldValue.increment(steps),
      "totalSteps": FieldValue.increment(steps),
      "dailyDistance": FieldValue.increment(distance),
      "dailyCalories": FieldValue.increment(calories),
      "xp": FieldValue.increment(steps ~/ 10),
      "lastActiveDate": FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementXP({required String uid, required int xpToAdd}) async {
    await firestore.collection("players").doc(uid).update({
      "xp": FieldValue.increment(xpToAdd),
    });
  }

  Future<void> unlockTeamAchievement(String teamId, String achievementId) async {
    await firestore.collection("teams").doc(teamId).update({
      "unlockedAchievements": FieldValue.arrayUnion([achievementId]),
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

    final playerRef = firestore.collection("players").doc(session.userId);
    // Update daily history for steps/distance
    final todayKey = DateTime.now().toIso8601String().split('T')[0];
    await playerRef.update({
      "dailyHistory.$todayKey.walks": FieldValue.increment(1),
    });
  }

  Future<void> sendTacticalPing(String teamId, String channel, String message) async {
    await firestore.collection("teams").doc(teamId).collection("pings").add({
      "channel": channel,
      "message": message,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Future<void> createTeam({required String name, required String leaderId}) async {
    // Check if team name is already taken (Optional but recommended)
    final existingTeams = await firestore.collection("teams").where("name", isEqualTo: name).get();
    if (existingTeams.docs.isNotEmpty) {
      throw Exception("TEAM_NAME_TAKEN");
    }

    // Limit check: Prevent flooding (e.g., max 100 teams globally or per user)
    // For now, let's just ensure the user isn't already in a team (already handled in UI but good to have here)
    final playerDoc = await firestore.collection("players").doc(leaderId).get();
    if (!playerDoc.exists) throw Exception("PLAYER_NOT_FOUND");
    final player = PlayerModel.fromMap(playerDoc.data()!);

    if (player.isInTeam) {
      throw Exception("PLAYER_ALREADY_IN_TEAM");
    }

    final teamRef = firestore.collection("teams").doc();
    final team = TeamModel(
      id: teamRef.id,
      name: name,
      color: "purple",
      members: 1,
      maxMembers: 5,
      totalSteps: player.dailySteps, // Team starts with leader's current effort
      dailySteps: player.dailySteps,
      weeklySteps: player.weeklySteps,
      leaderId: leaderId,
      strongholdActive: false,
      logo: "shield",
      territoryCount: 0,
    );

    await firestore.runTransaction((transaction) async {
      transaction.set(teamRef, team.toMap());
      transaction.update(firestore.collection("players").doc(leaderId), {
        "isInTeam": true,
        "teamId": teamRef.id,
        "team": name,
      });
    });
  }

  Stream<List<TeamModel>> getTeams() {
    return firestore.collection("teams").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TeamModel.fromMap(doc.data())).toList();
    });
  }

  Stream<TeamModel?> getTeamStream(String teamId) {
    if (teamId.isEmpty) return Stream.value(null);
    return firestore.collection("teams").doc(teamId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return TeamModel.fromMap(snapshot.data()!);
    });
  }

  Stream<TeamChallengeModel?> getActiveTeamChallengeStream(String teamId, String challengeId) {
    if (teamId.isEmpty || challengeId.isEmpty) return Stream.value(null);
    return firestore
        .collection("teams")
        .doc(teamId)
        .collection("challenges")
        .doc(challengeId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return TeamChallengeModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  Future<void> sendTeamChatMessage(String teamId, String senderId, String senderName, String message) async {
    await firestore.collection("teams").doc(teamId).collection("messages").add({
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ChatMessageModel>> getTeamMessages(String teamId) {
    return firestore
        .collection("teams")
        .doc(teamId)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id)).toList();
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
      double energyBoostMult = player.energyBoostRaidMultiplier;

      double totalDmg = (baseDmg * gearMult * strongholdBonus * energyBoostMult * elementalMult).toDouble();

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

      // Update active challenge progress if it's a raid damage challenge
      final challengeId = teamSnap.data()?["activeDailyChallengeId"];
      if (challengeId != null) {
        final challengeRef = teamRef.collection("challenges").doc(challengeId);
        final challengeSnap = await transaction.get(challengeRef);
        if (challengeSnap.exists && challengeSnap.data()?["type"] == "raidDamage") {
          final double oldProgress = (challengeSnap.data()?["progress"] ?? 0.0).toDouble();
          final double target = (challengeSnap.data()?["target"] ?? 0.0).toDouble();
          final double newProgress = oldProgress + totalDmg;

          transaction.update(challengeRef, {
            "progress": newProgress,
          });

          if (oldProgress < target && newProgress >= target) {
            transaction.set(firestore.collection("activity_feed").doc(), {
              "teamId": teamId,
              "type": "challenge_completed",
              "itemId": challengeSnap.data()?["title"],
              "timestamp": FieldValue.serverTimestamp(),
            });
          }
        }
      }

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
          "unlockedAchievements": FieldValue.arrayUnion(['team_raid_slayer']),
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

        final teamSize = participantsQuery.docs.length;
        final rewards = GameplayRules.calculateRaidRewards(teamSize, ratio, true);

        int xpReward = rewards["xp"]!;
        int currencyReward = rewards["currency"]!;

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

  Future<void> completeWorldEvent(String eventId) async {
    final eventRef = firestore.collection("world_events").doc(eventId);

    await firestore.runTransaction((transaction) async {
      final eventSnap = await transaction.get(eventRef);
      if (!eventSnap.exists) return;

      final event = WorldEventModel.fromMap(eventSnap.data()!, eventId);
      if (!event.isActive) return;

      // 1. Determine Winning Team and Ranks
      final sortedTeams = event.teamContributions.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (sortedTeams.isEmpty) {
        transaction.update(eventRef, {"isActive": false});
        return;
      }

      final winningTeamId = sortedTeams.first.key;

      // 2. Distribute Rewards to Participating Teams
      for (int i = 0; i < sortedTeams.length; i++) {
        final teamId = sortedTeams[i].key;
        final rank = i + 1;

        // Calculate rewards using rules
        final teamRewards = GameplayRules.calculateWorldEventRewards(
          rank: rank,
          eventBaseRewards: event.rewards,
        );

        // Add to Team Currency
        final teamRef = firestore.collection("teams").doc(teamId);
        transaction.update(teamRef, {
          "teamCurrency": FieldValue.increment(teamRewards["currency"] ?? 0),
        });

        // Log team achievement if they won
        if (rank == 1) {
          transaction.update(teamRef, {
            "unlockedAchievements": FieldValue.arrayUnion(["world_event_winner"]),
          });
        }

        // Notify team via activity feed
        transaction.set(firestore.collection("activity_feed").doc(), {
          "teamId": teamId,
          "type": "world_event_finished",
          "itemId": event.title,
          "message": "Ranked #$rank in ${event.title}! Rewards distributed.",
          "timestamp": FieldValue.serverTimestamp(),
        });
      }

      transaction.update(eventRef, {
        "isActive": false,
        "winningTeamId": winningTeamId,
      });
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

      double eventXpMult = player.getModifier('event_xp_mult', allGear);
      int xpReward = ((25 + (bonus * 10)) * eventXpMult).toInt();

      transaction.update(playerRef, {
        "currentStamina": player.currentStamina - cost,
        "xp": FieldValue.increment(xpReward),
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

      final player = PlayerModel.fromMap(snapshot.data()!);
      int current = player.currentStamina;
      int max = player.maxStamina;

      if (current < max) {
        // Scaling: Base regen + 1 for every 2 points of effective Endurance
        int bonusRegen = (player.effectiveEndurance / 2).floor();
        int totalRegen = GameplayRules.passiveStaminaRegen + bonusRegen;

        transaction.update(docRef, {
          "currentStamina": (current + totalRegen).clamp(0, max),
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
    final tileRef = firestore.collection("hex_tiles").doc(tile.tileId);

    await firestore.runTransaction((transaction) async {
      final tileSnap = await transaction.get(tileRef);

      if (tileSnap.exists) {
        final oldData = tileSnap.data()!;
        final String oldOwnerId = oldData["ownerId"];
        final String oldOwnerType = oldData["ownerType"];

        if (oldOwnerId != tile.ownerId) {
          // Decrement old owner
          if (oldOwnerType == "team") {
            final oldTeamRef = firestore.collection("teams").doc(oldOwnerId);
            transaction.update(oldTeamRef, {"territoryCount": FieldValue.increment(-1)});
          } else if (oldOwnerType == "solo") {
            final oldPlayerRef = firestore.collection("players").doc(oldOwnerId);
            transaction.update(oldPlayerRef, {"totalLand": FieldValue.increment(-1)});
          }

          // Increment new owner
          if (tile.ownerType == "team") {
            final teamRef = firestore.collection("teams").doc(tile.ownerId);
            transaction.update(teamRef, {"territoryCount": FieldValue.increment(1)});
          } else if (tile.ownerType == "solo") {
            final playerRef = firestore.collection("players").doc(tile.ownerId);
            transaction.update(playerRef, {"totalLand": FieldValue.increment(1)});

            // Log the capture in the activity feed
            final activityRef = firestore.collection("activity_feed").doc();
            transaction.set(activityRef, {
              "userId": tile.ownerId,
              "playerName": tile.ownerName,
              "type": "capture",
              "message": "captured a new territory sector",
              "timestamp": FieldValue.serverTimestamp(),
            });

            // Update daily captures in player history
            final todayKey = DateTime.now().toIso8601String().split('T')[0];
            transaction.update(playerRef, {
              "dailyHistory.$todayKey.captures": FieldValue.increment(1),
            });
          }
        }
      } else {
        // New tile being captured for the first time
        if (tile.ownerType == "team") {
          final teamRef = firestore.collection("teams").doc(tile.ownerId);
          transaction.update(teamRef, {"territoryCount": FieldValue.increment(1)});
        } else if (tile.ownerType == "solo") {
          final playerRef = firestore.collection("players").doc(tile.ownerId);
          transaction.update(playerRef, {"totalLand": FieldValue.increment(1)});
        }
      }

      // Always set the tile data (it might be a repair or power update)
      transaction.set(tileRef, tile.toMap());
    });
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

      anomaly.rewards.forEach((item, amount) {
        if (item == "XP") {
          xpReward += (amount as num).toInt();
        } else {
          inventory[item] = (inventory[item] ?? 0) + (amount as num).toInt();
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

  Future<void> updateLastHardwareSteps({required String uid, required int hardwareSteps}) async {
    await firestore.collection("players").doc(uid).update({
      "lastHardwareStepCount": hardwareSteps,
    });
  }

  Future<Map<String, dynamic>> syncTelemetry({
    required String uid,
    required int deltaSteps,
    required int currentHardwareSteps,
    required PlayerModel player,
  }) async {
    final playerRef = firestore.collection("players").doc(uid);
    final teamRef = player.teamId != null ? firestore.collection("teams").doc(player.teamId) : null;

    final calories = (deltaSteps * GameplayRules.caloriesPerStep).toInt();
    final distance = deltaSteps * GameplayRules.distanceKmPerStep;

    double xpMult = player.getModifier('xp_mult', allGear);
    double stepXpMult = player.getModifier('step_xp_mult', allGear);
    final xp = ((deltaSteps / 10) * player.energyBoostXpMultiplier * xpMult * stepXpMult).toInt();
    
    // Correct stamina refill logic based on GameplayRules
    final apRegained = GameplayRules.calculateStaminaRefill(deltaSteps, player.effectiveEndurance);

    final dateKey = DateTime.now().toIso8601String().split('T')[0];
    final hourKey = DateTime.now().hour.toString();

    Map<String, dynamic> resultUpdates = {};

    await firestore.runTransaction((transaction) async {
      final playerSnap = await transaction.get(playerRef);
      if (!playerSnap.exists) return;

      final data = playerSnap.data()!;

      // Manually handle nested map entries to ensure they exist before incrementing
      Map<String, dynamic> dailyHistory = Map<String, dynamic>.from(data["dailyHistory"] ?? {});
      Map<String, dynamic> dayEntry = Map<String, dynamic>.from(dailyHistory[dateKey] ?? {});
      dayEntry["steps"] = (dayEntry["steps"] ?? 0) + deltaSteps;
      dailyHistory[dateKey] = dayEntry;

      Map<String, int> hourlySteps = Map<String, int>.from(data["hourlySteps"] ?? {});
      hourlySteps[hourKey] = (hourlySteps[hourKey] ?? 0) + deltaSteps;

      final playerUpdates = {
        "lastHardwareStepCount": currentHardwareSteps,
        "totalSteps": FieldValue.increment(deltaSteps),
        "dailySteps": FieldValue.increment(deltaSteps),
        "weeklySteps": FieldValue.increment(deltaSteps),
        "dailyCalories": FieldValue.increment(calories),
        "dailyDistance": FieldValue.increment(distance),
        "lastActiveDate": FieldValue.serverTimestamp(),
        "xp": FieldValue.increment(xp),
        "currentStamina": FieldValue.increment(apRegained),
        "lastSyncTime": FieldValue.serverTimestamp(),
        "dailyHistory": dailyHistory,
        "hourlySteps": hourlySteps,
      };

      resultUpdates = playerUpdates;

      // 1. Update Player
      transaction.update(playerRef, playerUpdates);

      // 2. Update Team (if applicable)
      if (teamRef != null) {
        final teamSnap = await transaction.get(teamRef);
        if (teamSnap.exists) {
          final teamData = teamSnap.data()!;

          transaction.update(teamRef, {
            "totalSteps": FieldValue.increment(deltaSteps),
            "dailySteps": FieldValue.increment(deltaSteps),
            "weeklySteps": FieldValue.increment(deltaSteps),
          });

          // 3. Update Team Challenge Progress
          final challengeId = teamData["activeDailyChallengeId"];
          if (challengeId != null) {
            final challengeRef = teamRef.collection("challenges").doc(challengeId);
            final challengeSnap = await transaction.get(challengeRef);
            if (challengeSnap.exists) {
              final challengeData = challengeSnap.data()!;
              final type = challengeData["type"];
              double increment = (type == "distance") ? distance : (type == "steps" ? deltaSteps.toDouble() : 0);

              if (increment > 0) {
                final double oldProgress = (challengeData["progress"] ?? 0.0).toDouble();
                final double target = (challengeData["target"] ?? 0.0).toDouble();
                final double newProgress = oldProgress + increment;

                transaction.update(challengeRef, {"progress": newProgress});

                if (oldProgress < target && newProgress >= target) {
                  transaction.set(firestore.collection("activity_feed").doc(), {
                    "teamId": player.teamId,
                    "type": "challenge_completed",
                    "itemId": challengeData["title"],
                    "timestamp": FieldValue.serverTimestamp(),
                  });
                }
              }
            }
          }
        }
      }
    });

    _clampPlayerStamina(uid);
    await contributeToGlobalEvent(uid: uid, steps: deltaSteps);

    return resultUpdates;
  }

  Future<void> _clampPlayerStamina(String uid) async {
    final docRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      int current = (data["currentStamina"] as num?)?.toInt() ?? 0;
      int max = (data["maxStamina"] as num?)?.toInt() ?? GameplayRules.baseMaxStamina;
      if (current > max) {
        transaction.update(docRef, {"currentStamina": max});
      }
    });
  }

  Future<void> claimMineralNode(String uid, String material) async {
    final playerRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(playerRef);
      if (!snapshot.exists) return;

      Map<String, int> inventory = Map<String, int>.from(snapshot.data()?["inventory"] ?? {});
      inventory[material] = (inventory[material] ?? 0) + 1;

      transaction.update(playerRef, {
        "inventory": inventory,
        "xp": FieldValue.increment(50),
      });
    });
  }

  Future<void> updateTeamSteps({required String teamId, required int stepsToAdd}) async {
    final teamRef = firestore.collection("teams").doc(teamId);

    await firestore.runTransaction((transaction) async {
      final teamSnap = await transaction.get(teamRef);
      if (!teamSnap.exists) return;

      final data = teamSnap.data()!;
      final currentSteps = (data["totalSteps"] ?? 0) as int;
      final newSteps = currentSteps + stepsToAdd;

      final currentDailySteps = (data["dailySteps"] ?? 0) as int;
      final newDailySteps = currentDailySteps + stepsToAdd;

      final currentWeeklySteps = (data["weeklySteps"] ?? 0) as int;
      final newWeeklySteps = currentWeeklySteps + stepsToAdd;

      final List<String> unlocked = List<String>.from(data["unlockedAchievements"] ?? []);

      Map<String, dynamic> updates = {
        "totalSteps": newSteps,
        "dailySteps": newDailySteps,
        "weeklySteps": newWeeklySteps,
      };

      // Achievement: 100k Steps
      if (newSteps >= 100000 && !unlocked.contains('team_first_100k')) {
        updates["unlockedAchievements"] = FieldValue.arrayUnion(['team_first_100k']);
      }

      transaction.update(teamRef, updates);

      // Update active challenge progress if it's a step challenge
      final challengeId = data["activeDailyChallengeId"];
      if (challengeId != null) {
        final challengeRef = teamRef.collection("challenges").doc(challengeId);
        final challengeSnap = await transaction.get(challengeRef);
        if (challengeSnap.exists && challengeSnap.data()?["type"] == "steps") {
          final double oldProgress = (challengeSnap.data()?["progress"] ?? 0.0).toDouble();
          final double target = (challengeSnap.data()?["target"] ?? 0.0).toDouble();
          final double newProgress = oldProgress + stepsToAdd;

          transaction.update(challengeRef, {
            "progress": newProgress,
          });

          // Trigger completion event if target reached
          if (oldProgress < target && newProgress >= target) {
            transaction.set(firestore.collection("activity_feed").doc(), {
              "teamId": teamId,
              "type": "challenge_completed",
              "itemId": challengeSnap.data()?["title"],
              "timestamp": FieldValue.serverTimestamp(),
            });
          }
        }
      }
    });
  }

  Stream<TeamChallengeModel?> getActiveTeamChallenge(String teamId) {
    return firestore
        .collection("teams")
        .doc(teamId)
        .collection("challenges")
        .where("expiresAt", isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      // Return the one that expires soonest or is most recent
      final doc = snapshot.docs.first;
      return TeamChallengeModel.fromMap(doc.data(), doc.id);
    });
  }

  Future<void> rotateDailyChallenge(String teamId) async {
    final teamRef = firestore.collection("teams").doc(teamId);

    await firestore.runTransaction((transaction) async {
      final teamSnap = await transaction.get(teamRef);
      if (!teamSnap.exists) return;

      final data = teamSnap.data()!;
      final lastReset = (data["lastDailyReset"] as Timestamp?)?.toDate();
      final now = DateTime.now();

      // Check if it's actually a new day
      if (lastReset != null &&
          lastReset.year == now.year &&
          lastReset.month == now.month &&
          lastReset.day == now.day) {
        return;
      }

      // 1. Reset daily stats
      transaction.update(teamRef, {
        "dailySteps": 0,
        "lastDailyReset": Timestamp.fromDate(now),
      });

      // 2. Pick a new challenge from the pool
      final pool = GameplayRules.dailyChallengePool;
      final challengeData = pool[Random().nextInt(pool.length)];

      final challengeRef = teamRef.collection("challenges").doc();
      final expiresAt = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final newChallenge = TeamChallengeModel(
        id: challengeRef.id,
        title: challengeData["title"],
        description: challengeData["description"],
        scope: ChallengeScope.daily,
        type: ChallengeType.values.firstWhere((e) => e.name == challengeData["type"]),
        target: challengeData["target"],
        xpReward: challengeData["xp"],
        currencyReward: challengeData["currency"],
        expiresAt: expiresAt,
      );

      transaction.set(challengeRef, newChallenge.toMap());
      transaction.update(teamRef, {
        "activeDailyChallengeId": challengeRef.id,
      });

      // 3. Log to activity feed for notification triggers
      transaction.set(firestore.collection("activity_feed").doc(), {
        "teamId": teamId,
        "type": "challenge_started",
        "itemId": newChallenge.title,
        "timestamp": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> claimTeamChallengeReward(String teamId, String challengeId, String uid) async {
    final teamRef = firestore.collection("teams").doc(teamId);
    final challengeRef = teamRef.collection("challenges").doc(challengeId);
    final playerRef = firestore.collection("players").doc(uid);

    await firestore.runTransaction((transaction) async {
      final challengeSnap = await transaction.get(challengeRef);
      if (!challengeSnap.exists) throw Exception("CHALLENGE_NOT_FOUND");

      final challenge = TeamChallengeModel.fromMap(challengeSnap.data()!, challengeId);
      if (!challenge.isCompleted) throw Exception("CHALLENGE_NOT_COMPLETED");
      if (challenge.claimedMembers.contains(uid)) throw Exception("REWARD_ALREADY_CLAIMED");

      // 1. Mark as claimed for this player
      transaction.update(challengeRef, {
        "claimedMembers": FieldValue.arrayUnion([uid]),
      });

      // 2. Add rewards to player and team currency
      transaction.update(playerRef, {
        "xp": FieldValue.increment(challenge.xpReward),
        "currency": FieldValue.increment(challenge.currencyReward),
      });

      transaction.update(teamRef, {
        "teamCurrency": FieldValue.increment(challenge.currencyReward),
      });

      // Notify others that a member claimed reward
      transaction.set(firestore.collection("activity_feed").doc(), {
        "teamId": teamId,
        "userId": uid,
        "type": "reward_claimed",
        "itemId": challenge.title,
        "timestamp": FieldValue.serverTimestamp(),
      });

      // 3. Log to activity feed
      transaction.set(firestore.collection("activity_feed").doc(), {
        "userId": uid,
        "type": "team_challenge_reward",
        "itemId": challenge.title,
        "timestamp": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> logActivity(ActivityFeedModel activity) async {
    await firestore.collection("activity_feed").add(activity.toMap());
  }

  Future<void> contributeToGlobalEvent({required String uid, required int steps}) async {
    final eventQuery = await firestore
        .collection("world_events")
        .where("isActive", isEqualTo: true)
        .where("type", isEqualTo: "global_steps")
        .limit(1)
        .get();

    if (eventQuery.docs.isEmpty) return;

    final eventDoc = eventQuery.docs.first;
    await eventDoc.reference.update({
      "currentSteps": FieldValue.increment(steps),
    });
  }

  Future<void> checkAndResetDailyStats(String uid, {int? currentHardwareSteps}) async {
    final playerRef = firestore.collection("players").doc(uid);

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(playerRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final lastActive = data["lastActiveDate"] is Timestamp
          ? (data["lastActiveDate"] as Timestamp).toDate()
          : null;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (lastActive == null || lastActive.isBefore(today)) {
        // It's a new day!
        // 1. Archive yesterday's stats
        final dateKey = lastActive != null
            ? "${lastActive.year}-${lastActive.month.toString().padLeft(2, '0')}-${lastActive.day.toString().padLeft(2, '0')}"
            : "initial";

        Map<String, dynamic> dailyHistory = Map<String, dynamic>.from(data["dailyHistory"] ?? {});
        dailyHistory[dateKey] = {
          "steps": data["dailySteps"] ?? 0,
          "calories": data["dailyCalories"] ?? 0,
          "distance": data["dailyDistance"] ?? 0.0,
          "timestamp": data["lastActiveDate"] ?? FieldValue.serverTimestamp(),
        };

        // 2. Weekly Reset Logic
        bool isWeeklyReset = false;
        if (lastActive != null) {
          // Check if today is Monday (1) and lastActive was before this Monday
          final now = DateTime.now();
          final lastMonday = now.subtract(Duration(days: now.weekday - 1));
          final lastMondayMidnight = DateTime(lastMonday.year, lastMonday.month, lastMonday.day);

          if (lastActive.isBefore(lastMondayMidnight)) {
            isWeeklyReset = true;
          }
        }

        // 3. Update streaks
        int streak = data["streakCount"] ?? 0;
        String? lastStreakUpdateDate = data["lastStreakUpdateDate"];
        final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

        if (lastActive != null) {
          final yesterday = today.subtract(const Duration(days: 1));
          final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
          final lastActiveDay = DateTime(lastActive.year, lastActive.month, lastActive.day);

          if (lastActiveDay == yesterday) {
            // Check if they met their daily target to maintain/increment streak
            final int dailyTarget = data["dailyStepTarget"] ?? 10000;
            if ((data["dailySteps"] ?? 0) >= dailyTarget) {
              if (lastStreakUpdateDate != todayStr) {
                streak++;
                lastStreakUpdateDate = todayStr;
              }
            } else {
              // Target missed, reset streak
              streak = 0;
            }
          } else if (lastActiveDay == today) {
            // Already processed today
          } else if (lastActiveDay.isBefore(yesterday)) {
            streak = 0;
          }
        } else {
          // First time activity
          streak = 0;
        }

        Map<String, dynamic> playerUpdates = {
          "dailySteps": 0,
          "dailyCalories": 0,
          "dailyDistance": 0.0,
          "lastActiveDate": Timestamp.fromDate(today),
          "dailyHistory": dailyHistory,
          "streakCount": streak,
          "lastStreakUpdateDate": lastStreakUpdateDate,
          "hourlySteps": {}, // Reset hourly telemetry for the new day
        };

        // Anchor the new day's hardware baseline if current steps are known
        if (currentHardwareSteps != null && currentHardwareSteps > 0) {
          playerUpdates["lastHardwareStepCount"] = currentHardwareSteps;
        }

        if (isWeeklyReset) {
          playerUpdates["weeklySteps"] = 0;
        }

        transaction.update(playerRef, playerUpdates);

        // 4. Handle Team Daily Reset if player is in a team
        // FIX: this call was previously not awaited. _checkAndResetTeamDaily
        // does its own transaction.get()/transaction.update() calls, and
        // Firestore transactions require ALL reads to finish before ANY
        // writes commit. Without awaiting, the outer transaction could
        // finish (and commit) before the inner get/update pair completed,
        // which can throw a Firestore transaction error or just silently
        // skip the team's daily reset.
        if (data["isInTeam"] == true && data["teamId"] != null) {
          final teamId = data["teamId"];
          await _checkAndResetTeamDaily(transaction, teamId, isWeeklyReset);
        }
      }
    });
  }

  Future<void> _checkAndResetTeamDaily(Transaction transaction, String teamId, bool isWeeklyReset) async {
    final teamRef = firestore.collection("teams").doc(teamId);
    final teamSnap = await transaction.get(teamRef);
    if (!teamSnap.exists) return;

    final teamData = teamSnap.data()!;
    final lastReset = teamData["lastDailyReset"] is Timestamp
        ? (teamData["lastDailyReset"] as Timestamp).toDate()
        : null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastReset == null || lastReset.isBefore(today)) {
      final dateKey = lastReset != null
          ? "${lastReset.year}-${lastReset.month.toString().padLeft(2, '0')}-${lastReset.day.toString().padLeft(2, '0')}"
          : "initial";

      Map<String, dynamic> dailyHistory = Map<String, dynamic>.from(teamData["dailyHistory"] ?? {});
      dailyHistory[dateKey] = {
        "steps": teamData["dailySteps"] ?? 0,
        "territory": teamData["territoryCount"] ?? 0,
        "timestamp": teamData["lastDailyReset"] ?? FieldValue.serverTimestamp(),
      };

      Map<String, dynamic> teamUpdates = {
        "dailySteps": 0,
        "lastDailyReset": Timestamp.fromDate(today),
        "dailyHistory": dailyHistory,
      };

      if (isWeeklyReset) {
        Map<String, dynamic> weeklyHistory = Map<String, dynamic>.from(teamData["weeklyHistory"] ?? {});
        final weekKey = "${now.year}-W${(now.day / 7).ceil()}"; // Simple week key
        weeklyHistory[weekKey] = teamData["weeklySteps"] ?? 0;

        teamUpdates["weeklySteps"] = 0;
        teamUpdates["weeklyHistory"] = weeklyHistory;

        // Also reset individual weekly steps for all team members
        final membersQuery = await firestore.collection("players").where("teamId", isEqualTo: teamId).get();
        for (var doc in membersQuery.docs) {
          transaction.update(doc.reference, {"weeklySteps": 0});
        }
      }

      transaction.update(teamRef, teamUpdates);
    }
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

  Future<void> updatePlayerName({required String uid, required String name}) async {
    await firestore.collection("players").doc(uid).update({"name": name});
  }

  Future<void> updateTerritoryColor(String uid, String colorHex) async {
    await firestore.collection("players").doc(uid).update({"territoryColor": colorHex});
  }

  Future<void> updateAvatar({required String uid, required String avatarUrl}) async {
    await firestore.collection("players").doc(uid).update({"avatar": avatarUrl});
  }

  Future<String> uploadAvatarFile(String uid, Uint8List bytes) async {
    final ref = storage.ref().child('avatars').child('$uid.jpg');
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(bytes, metadata);
    return await ref.getDownloadURL();
  }

  Future<List<PlayerModel>> searchPlayers(String query) async {
    final snapshot = await firestore
        .collection("players")
        .where("name", isGreaterThanOrEqualTo: query)
        .where("name", isLessThanOrEqualTo: "$query\uf8ff")
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => PlayerModel.fromMap(doc.data())).toList();
  }

  Future<void> addFriend(String uid, String friendUid) async {
    await firestore.collection("players").doc(uid).update({
      "friends": FieldValue.arrayUnion([friendUid]),
    });
    // For bidirectional friendship
    await firestore.collection("players").doc(friendUid).update({
      "friends": FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> removeFriend(String uid, String friendUid) async {
    await firestore.collection("players").doc(uid).update({
      "friends": FieldValue.arrayRemove([friendUid]),
    });
    // For bidirectional friendship
    await firestore.collection("players").doc(friendUid).update({
      "friends": FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> equipGear(String uid, GearModel gear) async {
    final docRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final Map<String, dynamic> equipped = Map<String, dynamic>.from(data["equippedGear"] ?? {});
      equipped[gear.slot.name] = gear.id;

      transaction.update(docRef, {"equippedGear": equipped});
    });
  }

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
      final currentCurrency = (data["currency"] ?? 0) as int;

      if (currentCurrency >= cost) {
        transaction.update(docRef, {
          "currency": currentCurrency - cost,
          "activePowerUp": powerUpId,
          "powerUpExpiry": Timestamp.fromDate(DateTime.now().add(duration)),
        });
      } else {
        throw Exception("Insufficient funds");
      }
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

  Stream<List<PlayerModel>> getWeeklyLeaderboard() {
    return firestore
        .collection("players")
        .orderBy("weeklySteps", descending: true)
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

  // TEAM JOIN REQUEST OPERATIONS
  Future<void> sendJoinRequest(TeamRequestModel request) async {
    // Service-level check to prevent players already in a team from sending requests
    final playerDoc = await firestore.collection("players").doc(request.playerId).get();
    if (playerDoc.exists && (playerDoc.data()?["isInTeam"] ?? false)) {
      throw Exception("PLAYER_ALREADY_IN_TEAM");
    }
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
    await firestore.runTransaction((transaction) async {
      final playerRef = firestore.collection("players").doc(playerId);
      final teamRef = firestore.collection("teams").doc(teamId);
      final requestRef = firestore.collection("team_requests").doc(requestId);

      final teamSnap = await transaction.get(teamRef);
      if (!teamSnap.exists) throw Exception("TEAM_NOT_FOUND");

      final teamData = teamSnap.data()!;
      final members = (teamData["members"] ?? 0) as int;
      final maxMembers = (teamData["maxMembers"] ?? 5) as int;

      if (members >= maxMembers) {
        throw Exception("TEAM_FULL");
      }

      final playerSnap = await transaction.get(playerRef);
      if (playerSnap.exists && (playerSnap.data()?["isInTeam"] ?? false)) {
        transaction.update(requestRef, {"status": "expired"}); // Player joined another team
        throw Exception("PLAYER_ALREADY_IN_TEAM");
      }

      transaction.update(playerRef, {
        "isInTeam": true,
        "teamId": teamId,
        "team": teamName,
      });

      final newMemberCount = members + 1;
      Map<String, dynamic> teamUpdates = {
        "members": newMemberCount,
        "totalSteps": FieldValue.increment(playerSnap.data()?["dailySteps"] ?? 0),
        "dailySteps": FieldValue.increment(playerSnap.data()?["dailySteps"] ?? 0),
        "weeklySteps": FieldValue.increment(playerSnap.data()?["weeklySteps"] ?? 0),
      };

      if (newMemberCount >= maxMembers) {
        teamUpdates["unlockedAchievements"] = FieldValue.arrayUnion(['team_full_house']);
      }

      transaction.update(teamRef, teamUpdates);

      transaction.update(requestRef, {"status": "accepted"});
    });
  }

  Future<void> rejectRequest(String requestId) async {
    await firestore.collection("team_requests").doc(requestId).update({"status": "rejected"});
  }

  Future<void> ensurePlayerProfileExists(String uid, String email, String name) async {
    final doc = await firestore.collection("players").doc(uid).get();
    if (!doc.exists) {
      await createPlayer(uid: uid, name: name, email: email);
    }
  }

  Future<void> purchaseGear(String uid, GearModel gear) async {
    final playerRef = firestore.collection("players").doc(uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(playerRef);
      if (!snapshot.exists) throw Exception("Player profile not found");

      int xp = (snapshot.data()?["xp"] as num?)?.toInt() ?? 0;
      if (xp < gear.price) throw Exception("Insufficient XP to purchase this gear");

      transaction.update(playerRef, {
        "xp": xp - gear.price,
        "ownedGear": FieldValue.arrayUnion([gear.id]),
      });
    });
  }

  Future<Map<String, dynamic>> contributeRaidDamage(String teamId, double damage) async {
    final teamRef = firestore.collection("teams").doc(teamId);

    final result = await firestore.runTransaction((transaction) async {
      final teamSnap = await transaction.get(teamRef);
      if (!teamSnap.exists) return {"success": false, "defeated": false};

      double currentBossHp = (teamSnap.data()?["raidBossHp"] ?? 100000.0).toDouble();
      double newBossHp = (currentBossHp - damage).clamp(0.0, 1000000.0);
      double totalTeamDamage = (teamSnap.data()?["totalRaidDamage"] ?? 0.0) + damage;
      bool isDefeated = false;
      String? bossName;

      final updateData = <String, dynamic>{
        "totalRaidDamage": totalTeamDamage,
        "raidBossHp": newBossHp,
      };

      if (newBossHp <= 0) {
        isDefeated = true;
        final bossId = teamSnap.data()?["raidBossId"] ?? "void_titan";
        final bossConfig = bossPool.firstWhere((b) => b["id"] == bossId, orElse: () => bossPool[0]);
        bossName = bossConfig["name"];

        // Log victory
        final raidLogRef = teamRef.collection("raid_history").doc();
        transaction.set(raidLogRef, {
          "bossName": bossName,
          "timestamp": FieldValue.serverTimestamp(),
          "totalDamage": totalTeamDamage,
          "victorName": "Team Effort (Physical Activity)",
          "isSuccess": true,
        });

        // Spawn next boss
        final nextBoss = bossPool[Random().nextInt(bossPool.length)];
        updateData["raidBossId"] = nextBoss["id"];
        updateData["raidBossHp"] = nextBoss["maxHp"];
        updateData["raidActive"] = true;
        updateData["totalRaidDamage"] = 0.0;
        updateData["lastVictory"] = FieldValue.serverTimestamp();
        updateData["unlockedAchievements"] = FieldValue.arrayUnion(['team_raid_slayer']);
      }

      transaction.update(teamRef, updateData);

      return {
        "success": true,
        "defeated": isDefeated,
        "totalDamage": totalTeamDamage,
        "bossName": bossName,
      };
    });

    if (result["success"] == true && result["defeated"] == true) {
      await distributeRaidRewards(
        teamId: teamId,
        totalDamage: result["totalDamage"] as double,
        bossName: result["bossName"] as String,
      );
    }

    return result;
  }

  Future<void> contributeRaidDamageFromSteps({required String teamId, required String uid, required int steps}) async {
    final double damage = steps * GameplayRules.damagePerStep;

    // Update player's damage first so they are counted in rewards if boss dies
    await firestore.collection("players").doc(uid).update({
      "totalRaidDamage": FieldValue.increment(damage.toInt()),
    });

    await contributeRaidDamage(teamId, damage);
  }

  Future<void> updateGhostStriderToggle(String uid, bool enabled) async {
    await firestore.collection("players").doc(uid).update({
      "isGhostStriderEnabled": enabled,
    });
  }

  Future<void> updateBiometrics({
    required String uid,
    required double heightCm,
    required double weightKg,
    required String fitnessGoal,
    required int stepTarget,
    required int exerciseTarget,
    Map<String, int>? hourlySteps,
    Map<String, dynamic>? dailyHistory,
  }) async {
    final Map<String, dynamic> data = {
      "heightCm": heightCm,
      "weightKg": weightKg,
      "fitnessGoal": fitnessGoal,
      "dailyStepTarget": stepTarget,
      "dailyExerciseTargetMinutes": exerciseTarget,
    };
    if (hourlySteps != null) data["hourlySteps"] = hourlySteps;
    if (dailyHistory != null) data["dailyHistory"] = dailyHistory;

    await firestore.collection("players").doc(uid).update(data);
  }

  Stream<List<ActivityFeedModel>> getPlayerActivityStream(String uid, {ActivityType? type, int limit = 20}) {
    Query query = firestore.collection("activity_feed").where("userId", isEqualTo: uid);
    if (type != null) {
      query = query.where("type", isEqualTo: type.name);
    }
    return query
        .orderBy("timestamp", descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ActivityFeedModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    });
  }

  Stream<int> getPlayerRankStream(int totalLand) {
    // This query counts how many players have more land than the current player.
    // In a production environment with many users, this should be replaced by a
    // specialized leaderboard service or a cached rank field to reduce Firestore reads.
    return firestore
        .collection("players")
        .where("totalLand", isGreaterThan: totalLand)
        .snapshots()
        .map((snapshot) => snapshot.docs.length + 1);
  }

  Stream<List<ActivityFeedModel>> getActivityFeedStream({int limit = 10}) {
    return firestore
        .collection("activity_feed")
        .orderBy("timestamp", descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ActivityFeedModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<PlayerModel>> getTeamWeeklyLeaderboard(String teamId) {
    return firestore
        .collection("players")
        .where("teamId", isEqualTo: teamId)
        .orderBy("weeklySteps", descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PlayerModel.fromMap(doc.data())).toList();
    });
  }

  Stream<List<PlayerModel>> getTeamLeaderboard(String teamName) {
    return firestore
        .collection("players")
        .where("team", isEqualTo: teamName)
        .orderBy("totalSteps", descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PlayerModel.fromMap(doc.data())).toList();
    });
  }

  Stream<List<TeamModel>> getTeamLeaderboardGlobal() {
    return firestore
        .collection("teams")
        .orderBy("totalSteps", descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TeamModel.fromMap(doc.data())).toList();
    });
  }

  Stream<List<ActivityFeedModel>> getTeamActivityFeed(String teamId) {
    return firestore
        .collection("activity_feed")
        .where("teamId", isEqualTo: teamId)
        .orderBy("timestamp", descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ActivityFeedModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<ActivityFeedModel>> getTeamBuffHistory(String teamId) {
    return firestore
        .collection("activity_feed")
        .where("teamId", isEqualTo: teamId)
        .where("type", isEqualTo: "team_buff_activated")
        .orderBy("timestamp", descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ActivityFeedModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> purchaseTeamBuff(String teamId, Map<String, dynamic> buff) async {
    final teamRef = firestore.collection("teams").doc(teamId);

    await firestore.runTransaction((transaction) async {
      final teamSnap = await transaction.get(teamRef);
      if (!teamSnap.exists) return;

      final data = teamSnap.data()!;
      final int currentCurrency = (data["teamCurrency"] ?? 0) as int;
      final int cost = buff["cost"] as int;

      if (currentCurrency < cost) {
        throw Exception("INSUFFICIENT_TEAM_FUNDS");
      }

      Map<String, Timestamp> activeBuffs = Map<String, Timestamp>.from(data["activeTeamBuffs"] ?? {});

      DateTime now = DateTime.now();
      DateTime expiry = now.add(buff["duration"] as Duration);

      // Extend if already active
      if (activeBuffs.containsKey(buff["id"])) {
        DateTime currentExpiry = activeBuffs[buff["id"]]!.toDate();
        if (currentExpiry.isAfter(now)) {
          expiry = currentExpiry.add(buff["duration"] as Duration);
        }
      }

      activeBuffs[buff["id"]] = Timestamp.fromDate(expiry);

      transaction.update(teamRef, {
        "teamCurrency": currentCurrency - cost,
        "activeTeamBuffs": activeBuffs,
      });

      // Log to activity feed
      transaction.set(firestore.collection("activity_feed").doc(), {
        "teamId": teamId,
        "type": "team_buff_activated",
        "itemId": buff["name"],
        "message": "Activated ${buff['name']}",
        "timestamp": FieldValue.serverTimestamp(),
      });
    });
  }

  String getRankTitle(int level) {
    if (level >= 50) return "GRANDMASTER STRIDER";
    if (level >= 40) return "ELITE VANGUARD";
    if (level >= 30) return "VETERAN SCOUT";
    if (level >= 20) return "ADVANCED RECON";
    if (level >= 10) return "ACTIVE OPERATIVE";
    return "INITIATE RECRUIT";
  }

}