import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import '../../lib/services/firebase_service.dart';
import '../../lib/models/player_model.dart';
import '../../lib/config/gameplay_rules.dart';
import 'dart:async';

void main() {
  group('Firestore Quota Stress Test (Simulated)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late FirebaseService firebaseService;
    const String testUid = "stress_test_user";

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      // Injecting the fake firestore and mock auth into the service for testing
      firebaseService = FirebaseService(
        firestore: fakeFirestore,
        auth: mockAuth,
      );
    });

    test('High-frequency FieldValue.increment pulses', () async {
      // 1. Initialize player profile in the fake DB
      await firebaseService.createPlayer(
        uid: testUid,
        name: "Stress Tester",
        email: "stress@fitquest.io",
      );

      PlayerModel? player = await firebaseService.getPlayer(testUid);
      expect(player, isNotNull);

      // Simulate 100 rapid pulses (e.g., rapid walking/running detection)
      int pulseCount = 100; 
      int stepsPerPulse = 10;
      
      print("Simulating $pulseCount FieldValue.increment pulses...");
      
      Stopwatch sw = Stopwatch()..start();
      
      for (int i = 0; i < pulseCount; i++) {
        int currentHardware = 5000 + (i * stepsPerPulse);
        // Use the unified sync method that handles atomic FieldValue.increment
        final updates = await firebaseService.syncTelemetry(
          uid: testUid,
          deltaSteps: stepsPerPulse,
          currentHardwareSteps: currentHardware + stepsPerPulse,
          player: player!,
        );
        
        expect(updates, isA<Map<String, dynamic>>());
        expect(updates['dailySteps'], isA<FieldValue>());
        expect(updates['lastHardwareStepCount'], currentHardware + stepsPerPulse);

        // Optimistic local state update to mirror app behavior
        player = player.copyWith(
          dailySteps: player.dailySteps + stepsPerPulse,
          totalSteps: player.totalSteps + stepsPerPulse,
        );
      }
      
      sw.stop();
      print("Stress test completed in ${sw.elapsedMilliseconds}ms");
      
      // 2. Verification of data consistency
      final updatedPlayer = await firebaseService.getPlayer(testUid);
      expect(updatedPlayer, isNotNull);
      
      // Verify main step counters
      expect(updatedPlayer?.dailySteps, pulseCount * stepsPerPulse);
      expect(updatedPlayer?.totalSteps, pulseCount * stepsPerPulse);
      
      // Verify nested map updates (Hourly and Daily History buckets)
      final now = DateTime.now();
      final todayKey = now.toIso8601String().split('T')[0];
      final hourKey = now.hour.toString().padLeft(2, '0');
      
      expect(updatedPlayer?.hourlySteps[hourKey], pulseCount * stepsPerPulse);
      expect(updatedPlayer?.dailyHistory[todayKey]['steps'], pulseCount * stepsPerPulse);
      
      // Verify XP scaling (1 XP per 10 steps)
      expect(updatedPlayer?.xp, pulseCount * (stepsPerPulse ~/ 10));
    });

    test('Multi-metric batch integrity', () async {
      // Validates that all derived metrics (calories, distance) update correctly in a single sync
      await firebaseService.createPlayer(
        uid: "batch_user",
        name: "Batch Tester",
        email: "batch@fitquest.io",
      );

      final initial = await firebaseService.getPlayer("batch_user");
      
      await firebaseService.syncTelemetry(
        uid: "batch_user",
        deltaSteps: 1000,
        currentHardwareSteps: 1000,
        player: initial!,
      );

      final result = await firebaseService.getPlayer("batch_user");
      expect(result?.dailySteps, 1000);
      expect(result?.dailyCalories, (1000 * GameplayRules.caloriesPerStep).toInt());
      expect(result?.dailyDistance, 1000 * GameplayRules.distanceKmPerStep);
      expect(result?.xp, 100, reason: "Default XP should be steps / 10");
    });

    test('Step accuracy vs XP multiplier scaling (The 1x vs Multiplier Rule)', () async {
      const String boostUid = "boost_user";
      
      // 1. Initialize player
      await firebaseService.createPlayer(
        uid: boostUid,
        name: "Boost Tester",
        email: "boost@fitquest.io",
      );

      // 2. Set an active XP "Offer" (1.5x Multiplier)
      await fakeFirestore.collection("players").doc(boostUid).update({
        "energyBoostXpMultiplier": 1.5
      });

      PlayerModel? player = await firebaseService.getPlayer(boostUid);
      expect(player?.energyBoostXpMultiplier, 1.5);

      // 3. Walk 1000 physical steps
      await firebaseService.syncTelemetry(
        uid: boostUid,
        deltaSteps: 1000,
        currentHardwareSteps: 1000,
        player: player!,
      );

      final result = await firebaseService.getPlayer(boostUid);

      // 4. VERIFICATION:
      // Steps must be 1x (1000)
      expect(result?.dailySteps, 1000, reason: "Physical steps should always be 1x");
      
      // XP should be (1000 / 10) * 1.5 = 150
      expect(result?.xp, 150, reason: "XP should scale by the 1.5x multiplier");
      
      print("VERIFIED: 1000 steps -> 1000 daily steps (1x) and 150 XP (1.5x)");
    });

    test('Zero-activity day integrity (Ensures history shows 0 instead of ghost data)', () async {
      const String zeroUid = "zero_user";
      final todayKey = DateTime.now().toIso8601String().split('T')[0];

      // 1. Create a player but perform NO telemetry sync yet
      await firebaseService.createPlayer(
        uid: zeroUid,
        name: "Zero Tester",
        email: "zero@fitquest.io",
      );

      final result = await firebaseService.getPlayer(zeroUid);
      
      // 2. VERIFY: The history should exist but show 0 steps (not null or ghost data)
      // Note: We expect the dailyHistory entry to be initialized during player creation 
      // or to return 0 when accessed via the model.
      expect(result?.dailySteps, 0);
      expect(result?.dailyHistory[todayKey], isNull, reason: "Day entry should be null until first sync");
      
      // 3. Sync exactly 0 steps (e.g., a heartbeat sync)
      await firebaseService.syncTelemetry(
        uid: zeroUid,
        deltaSteps: 0,
        currentHardwareSteps: 100,
        player: result!,
      );
      
      final updated = await firebaseService.getPlayer(zeroUid);
      
      // 4. VERIFY: Now the entry exists but specifically shows 0.
      // This ensures the History Screen shows a clean "0" and not empty space or old data.
      expect(updated?.dailyHistory[todayKey]['steps'], 0, reason: "History must explicitly show 0 after a sync");
      expect(updated?.lastHardwareStepCount, 100);
    });

    test('Anchoring validation (Baseline Reset)', () async {
      const String anchorUid = "anchor_user";
      await firebaseService.createPlayer(uid: anchorUid, name: "Anchor", email: "a@b.com");
      
      // Initial state: lastHardwareStepCount is -1
      PlayerModel? player = await firebaseService.getPlayer(anchorUid);
      expect(player?.lastHardwareStepCount, -1);

      // 1. Simulate StepSyncService baseline anchoring (first connection)
      // StepSyncService logic: if (lastHardwareSteps <= 0) => updateLastHardwareSteps
      await firebaseService.updateLastHardwareSteps(uid: anchorUid, hardwareSteps: 5000);
      
      player = await firebaseService.getPlayer(anchorUid);
      expect(player?.lastHardwareStepCount, 5000);

      // 2. Simulate phone reboot (hardware count drops to 10)
      // StepSyncService logic: if (currentHardwareSteps < lastHardwareSteps) => updateLastHardwareSteps
      int rebootSteps = 10;
      if (rebootSteps < (player?.lastHardwareStepCount ?? 0)) {
         await firebaseService.updateLastHardwareSteps(uid: anchorUid, hardwareSteps: rebootSteps);
      }

      player = await firebaseService.getPlayer(anchorUid);
      expect(player?.lastHardwareStepCount, 10, reason: "Baseline should be anchored to 10 after reboot to prevent massive ghost delta");
      
      // 3. Next walk session: 10 -> 110 (delta 100)
      await firebaseService.syncTelemetry(
        uid: anchorUid,
        deltaSteps: 100,
        currentHardwareSteps: 110,
        player: player!,
      );

      player = await firebaseService.getPlayer(anchorUid);
      expect(player?.dailySteps, 100);
      expect(player?.lastHardwareStepCount, 110);
    });
  });
}
