import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/player_model.dart';
import '../services/firebase_service.dart';

class TeamMembersScreen extends StatelessWidget {
  final String teamName;
  final String teamId;
  final String leaderId;

  const TeamMembersScreen({
    super.key,
    required this.teamName,
    required this.teamId,
    required this.leaderId,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final bool isLeader = currentUid == leaderId;
    final FirebaseService firebaseService = FirebaseService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "${teamName.toUpperCase()} ROSTER",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("players")
            .where("team", isEqualTo: teamName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "NO SQUAD UNITS FOUND",
                style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            );
          }

          List<PlayerModel> members = snapshot.data!.docs.map((doc) {
            return PlayerModel.fromMap(doc.data() as Map<String, dynamic>);
          }).toList();

          members.sort((a, b) => b.totalSteps.compareTo(a.totalSteps));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final player = members[index];
              final bool playerIsLeader = player.uid == leaderId;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: playerIsLeader
                        ? Colors.orangeAccent.withValues(alpha: 0.4)
                        : Colors.grey.withValues(alpha: 0.15),
                    width: playerIsLeader ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: playerIsLeader
                                ? Colors.orangeAccent.withValues(alpha: 0.1)
                                : Colors.blueAccent.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: playerIsLeader ? Colors.orangeAccent : Colors.blueAccent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: player.avatar.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.network(player.avatar, fit: BoxFit.cover),
                          )
                              : Center(
                            child: Text(
                              "#${index + 1}",
                              style: TextStyle(
                                color: playerIsLeader ? Colors.orangeAccent : Colors.blueAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      player.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black87,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (playerIsLeader)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orangeAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                                      ),
                                      child: const Text(
                                        "COMMANDER",
                                        style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    "⚡ ${player.totalSteps} STEPS",
                                    style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "⭐ LVL ${player.level}",
                                    style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isLeader && !playerIsLeader) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                            foregroundColor: Colors.redAccent,
                            elevation: 0,
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            await firebaseService.kickPlayer(playerId: player.uid, teamId: teamId);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.redAccent,
                                content: Text("TERMINATED: ${player.name.toUpperCase()} PURGED FROM SQUAD"),
                              ),
                            );
                          },
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
                          label: const Text(
                            "KICK OPERATOR",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
