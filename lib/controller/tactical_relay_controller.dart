import 'package:cloud_firestore/cloud_firestore.dart';
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

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final challenge = TacticalRelayModel.fromMap(snapshot.data()!);
      
      // Safety Check: Ensure relay is still active and operator has met target
      if (!challenge.isActive || challenge.currentSteps < challenge.targetSteps) {
        return;
      }

      final currentIndex = challenge.sequence.indexOf(challenge.currentPlayerId);
      
      if (currentIndex != -1 && currentIndex < challenge.sequence.length - 1) {
        final nextPlayerId = challenge.sequence[currentIndex + 1];
        
        // Fetch next player name (Note: ideally this would be cached or part of the team doc)
        final nextPlayer = await _firebaseService.getPlayer(nextPlayerId);
        final nextName = nextPlayer?.name ?? "Operator ${currentIndex + 2}";
        
        transaction.update(docRef, {
          'currentPlayerId': nextPlayerId,
          'currentPlayerName': nextName,
          'currentSteps': 0,
          'startTime': FieldValue.serverTimestamp(),
        });

        // Notify the team via ping
        await _firebaseService.sendTacticalPing(
          teamId,
          "CHALLENGE_CHANNEL",
          "RELAY TOKEN TRANSFERRED TO ${nextName.toUpperCase()}"
        );
      } else {
        // Challenge finished - Atomic Deactivation
        transaction.update(docRef, {'isActive': false});
        
        // AWARD CURRENCY & XP TO ALL TEAM MEMBERS
        final playersSnapshot = await _firestore.collection('players').where('teamId', isEqualTo: teamId).get();
        for (var doc in playersSnapshot.docs) {
          await _firebaseService.updateCurrency(doc.id, 500); 
          await _firebaseService.incrementXP(uid: doc.id, xpToAdd: 1000);
        }

        await _firebaseService.sendTacticalPing(
          teamId,
          "CHALLENGE_CHANNEL",
          "TACTICAL STEP RELAY COMPLETE - 500 CREDITS & 1000 XP AWARDED TO ALL OPERATORS"
        );
      }
    });
  }
}
