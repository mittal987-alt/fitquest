import 'package:flutter/material.dart';
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "INBOUND SQUAD REQUESTS",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16, color: Colors.black87),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<List<TeamRequestModel>>(
        stream: firebaseService.getTeamRequests(teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "NO PENDING TELEMETRY REQUESTS",
                style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13),
              ),
            );
          }

          final requests = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
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
                    // APPLICANT DOSSIER INFO
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.person_search_rounded, color: Colors.greenAccent, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.playerName.toUpperCase(),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 0.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "REQUESTING LINK TO ${teamName.toUpperCase()}",
                                style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.2),
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
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent.withValues(alpha: 0.1),
                              foregroundColor: Colors.greenAccent,
                              elevation: 0,
                              side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.3)),
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
                                  backgroundColor: Colors.greenAccent,
                                  content: Text("ACCEPTED: ${request.playerName.toUpperCase()} ALLOCATED TO SQUAD"),
                                ),
                              );
                            },
                            child: const Text("GRANT ACCESS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
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
      ),
    );
  }
}