import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';

class RechargeBadge extends StatelessWidget {
  const RechargeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final uid = firebaseService.auth.currentUser?.uid;

    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("players").doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final powerUps = data["activePowerUps"] as Map<String, dynamic>? ?? {};
        final expiry = powerUps["metabolic_recharge"] as Timestamp?;
        final bool isRecharging = expiry != null && expiry.toDate().isAfter(DateTime.now());

        if (!isRecharging) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blueAccent, Colors.cyanAccent],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text(
                "RECHARGE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
