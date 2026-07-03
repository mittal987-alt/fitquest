import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/relay_model.dart';
import '../services/firebase_service.dart';

class RelayController {
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<RelayModel?> getTeamRelay(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .collection('active_relay')
        .doc('current')
        .snapshots()
        .map((doc) => doc.exists ? RelayModel.fromMap(doc.data()!) : null);
  }

  Future<void> startRelay({
    required String teamId,
    required List<String> sequence,
    required int targetPerOperator,
  }) async {
    if (sequence.isEmpty) return;

    final firstOperatorId = sequence.first;
    // In a real app, you'd fetch the name here
    const firstOperatorName = "Operator 1"; 

    final relay = RelayModel(
      teamId: teamId,
      currentOperatorId: firstOperatorId,
      currentOperatorName: firstOperatorName,
      targetSteps: targetPerOperator,
      currentSteps: 0,
      isActive: true,
      startTime: DateTime.now(),
      sequence: sequence,
    );

    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('active_relay')
        .doc('current')
        .set(relay.toMap());
  }

  Future<void> updateRelayProgress(String teamId, int steps) async {
    await _firestore
        .collection('teams')
        .doc(teamId)
        .collection('active_relay')
        .doc('current')
        .update({
      'currentSteps': FieldValue.increment(steps),
    });
  }

  Future<void> passRelay(String teamId) async {
    final docRef = _firestore
        .collection('teams')
        .doc(teamId)
        .collection('active_relay')
        .doc('current');

    final doc = await docRef.get();
    if (!doc.exists) return;

    final relay = RelayModel.fromMap(doc.data()!);
    final currentIndex = relay.sequence.indexOf(relay.currentOperatorId);
    
    if (currentIndex != -1 && currentIndex < relay.sequence.length - 1) {
      final nextOperatorId = relay.sequence[currentIndex + 1];
      // Fetch next operator name...
      
      await docRef.update({
        'currentOperatorId': nextOperatorId,
        'currentOperatorName': "Next Operator",
        'currentSteps': 0,
        'startTime': FieldValue.serverTimestamp(),
      });
    } else {
      // Relay finished
      await docRef.update({'isActive': false});
    }
  }
}
