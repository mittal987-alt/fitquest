import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';

class RaidBossScreen extends StatelessWidget {
  final String teamId;
  final FirebaseService _service = FirebaseService();

  RaidBossScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("teams").doc(teamId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final data = snapshot.data!.data() as Map<String, dynamic>;
        double hp = (data["raidBossHp"] ?? 100000.0).toDouble();
        double maxHp = 100000.0; // Define your max HP constant

        return Scaffold(
          appBar: AppBar(title: const Text("RAID BOSS: THE TITAN")),
          body: Column(
            children: [
              const SizedBox(height: 50),
              // HP Progress Bar
              LinearProgressIndicator(
                value: hp / maxHp,
                minHeight: 20,
                color: Colors.redAccent,
                backgroundColor: Colors.grey[200],
              ),
              Text("${hp.toInt()} HP Remaining"),
              const SizedBox(height: 30),

              // Attack Button
              ElevatedButton(
                onPressed: () async {
                  // Logic: Player consumes stamina + converts current steps to damage
                  await _service.contributeRaidDamage(teamId, 500.0);
                },
                child: const Text("ATTACK (Consume 500 Steps)"),
              ),
            ],
          ),
        );
      },
    );
  }
}