import 'package:flutter/material.dart';
import '../models/player_model.dart';
import '../models/team_request_model.dart';
import '../services/firebase_service.dart';

class TeamRequestsScreen extends StatelessWidget {
  final String teamId;
  final String teamName;

  const TeamRequestsScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: const Text(
          "INBOUND SQUAD REQUESTS",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<TeamRequestModel>>(
        stream: firebaseService.getTeamRequests(teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "NO PENDING TELEMETRY REQUESTS",
                style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13),
              ),
            );
          }

          final requests = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];

              return StreamBuilder<PlayerModel?>(
                stream: firebaseService.getPlayerStream(request.playerId),
                builder: (context, playerSnapshot) {
                  final player = playerSnapshot.data;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        // APPLICANT DOSSIER INFO
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                              ),
                              child: player?.avatar != null && player!.avatar.isNotEmpty
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.network(
                                  player.avatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person_search_rounded, color: Colors.blueAccent, size: 22),
                                ),
                              )
                                  : const Icon(Icons.person_search_rounded, color: Colors.blueAccent, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request.playerName.toUpperCase(),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "REQUESTING LINK TO ${teamName.toUpperCase()}",
                                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // COMMAND OPERATIONS PANEL BUTTONS
                        Row(
                          children: [
                            // REJECT INBOUND REQUEST
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                                  foregroundColor: Colors.redAccent,
                                  elevation: 0,
                                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () async {
                                  await firebaseService.rejectRequest(request.requestId);

                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.redAccent,
                                      content: Text("REJECTED: ${request.playerName.toUpperCase()} TRANSMISSION PURGED"),
                                    ),
                                  );
                                },
                                child: const Text("DENY ACCESS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // ACCEPT INBOUND REQUEST
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () async {
                                    await firebaseService.acceptRequest(
                                      requestId: request.requestId,
                                      playerId: request.playerId,
                                      teamId: request.teamId,
                                      teamName: request.teamName,
                                    );

                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF4A00E0),
                                        content: Text("ACCEPTED: ${request.playerName.toUpperCase()} ALLOCATED TO SQUAD"),
                                      ),
                                    );
                                  },
                                  child: const Text("GRANT ACCESS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}