import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_feed_model.dart';
import '../models/tactical_relay_model.dart';
import '../services/firebase_service.dart';

class TacticalRelayController {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<TacticalRelayModel?> getTeamRelay(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('active_tactical_relay')
        .doc('current')
        .snapshots()
        .map((doc) => doc.exists ? TacticalRelayModel.fromMap(doc.data()!) : null);
  }

  Future<void> startRelay({
    required String teamId,
    required List<String> sequence,
    required int targetPerPlayer,
    String playerName = "Player 1",
  }) async {
    if (sequence.isEmpty) return;

    final firstPlayerId = sequence.first;

    final challenge = TacticalRelayModel(
      teamId: teamId,
      currentPlayerId: firstPlayerId,
      currentPlayerName: playerName,
      targetSteps: targetPerPlayer,
      currentSteps: 0,
      isActive: true,
      startTime: DateTime.now(),
      sequence: sequence,
    );

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('active_tactical_relay')
        .doc('current')
        .set(challenge.toMap());

    // Log to Activity Feed
    final activity = ActivityFeedModel(
      id: "",
      teamId: teamId,
      playerName: playerName,
      type: ActivityType.relayStarted,
      message: "initiated a new Tactical Relay for the team!",
      timestamp: DateTime.now(),
    );
    await logActivity(activity);
  }

  Future<void> logActivity(ActivityFeedModel activity) async {
    await _firebaseService.logActivity(activity);
  }

  Future<void> updateRelayProgress(String teamId, int steps) async {
    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('active_tactical_relay')
        .doc('current')
        .update({
      'currentSteps': FieldValue.increment(steps),
    });
  }

  Future<void> passRelayToken(String teamId) async {
    final docRef = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('active_tactical_relay')
        .doc('current');

    String? activityMessage;
    String? currentPlayerName;
    ActivityType? activityType;
    bool isFinished = false;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final challenge = TacticalRelayModel.fromMap(snapshot.data()!);
      
      if (!challenge.isActive || challenge.currentSteps < challenge.targetSteps) {
        return;
      }

      currentPlayerName = challenge.currentPlayerName;
      final currentIndex = challenge.sequence.indexOf(challenge.currentPlayerId);
      
      if (currentIndex != -1 && currentIndex < challenge.sequence.length - 1) {
        final nextPlayerId = challenge.sequence[currentIndex + 1];
        
        // Transactional read for the next player's name
        final nextPlayerDoc = await transaction.get(_firestore.collection('players').doc(nextPlayerId));
        final nextName = nextPlayerDoc.data()?['name'] ?? "Operator ${currentIndex + 2}";
        
        transaction.update(docRef, {
          'currentPlayerId': nextPlayerId,
          'currentPlayerName': nextName,
          'currentSteps': 0,
          'startTime': FieldValue.serverTimestamp(),
        });

        activityType = ActivityType.relayTransferred;
        activityMessage = "transferred the relay baton to ${nextName.toUpperCase()}";
      } else {
        transaction.update(docRef, {'isActive': false});
        isFinished = true;
        activityType = ActivityType.relayCompleted;
        activityMessage = "finished the Tactical Relay! Rewards distributed to all operators.";
      }
    });

    // Execute side-effects (pings and rewards) outside the transaction
    if (activityMessage != null && activityType != null) {
      await _firebaseService.sendTacticalPing(
        teamId,
        "CHALLENGE_CHANNEL",
        "${currentPlayerName?.toUpperCase() ?? 'OPERATOR'} $activityMessage"
      );

      // Log to activity feed
      await logActivity(ActivityFeedModel(
        id: "",
        teamId: teamId,
        playerName: currentPlayerName,
        type: activityType!,
        message: activityMessage!,
        timestamp: DateTime.now(),
      ));
    }

    if (isFinished) {
      final playersSnapshot = await _firestore.collection('players').where('teamId', isEqualTo: teamId).get();
      for (var doc in playersSnapshot.docs) {
        await _firebaseService.updateCurrency(doc.id, 500); 
        await _firebaseService.incrementXP(uid: doc.id, xpToAdd: 1000);
      }
    }
  }
}
