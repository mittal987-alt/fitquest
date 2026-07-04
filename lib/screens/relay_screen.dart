import 'package:flutter/material.dart';
import '../controller/relay_controller.dart';
import '../models/relay_model.dart';
import '../services/firebase_service.dart';

class RelayScreen extends StatefulWidget {
  final String teamId;
  final String teamName;

  const RelayScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<RelayScreen> createState() => _RelayScreenState();
}

class _RelayScreenState extends State<RelayScreen> {
  final RelayController _relayController = RelayController();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "${widget.teamName.toUpperCase()} RELAY",
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
      body: StreamBuilder<RelayModel?>(
        stream: _relayController.getTeamRelay(widget.teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          final relay = snapshot.data;

          if (relay == null || !relay.isActive) {
            return _buildNoActiveRelay();
          }

          return _buildActiveRelay(relay);
        },
      ),
    );
  }

  Widget _buildNoActiveRelay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sync_alt_rounded, size: 80, color: Colors.black12),
          const SizedBox(height: 24),
          const Text(
            "NO ACTIVE TELEMETRY RELAY",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.black38,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Start a relay sequence to coordinate step goals across your squad and earn massive team XP bonuses.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showStartRelayDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              "INITIALIZE RELAY SEQUENCE",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRelay(RelayModel relay) {
    final currentUid = _firebaseService.auth.currentUser!.uid;
    final bool isMyTurn = relay.currentOperatorId == currentUid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isMyTurn ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "CURRENT OPERATOR",
                          style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isMyTurn ? "YOU (ACTIVE)" : relay.currentOperatorName.toUpperCase(),
                          style: TextStyle(
                            color: isMyTurn ? Colors.blueAccent : Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.sensors_rounded, color: Colors.blueAccent, size: 32),
                  ],
                ),
                const SizedBox(height: 32),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: relay.progress,
                        strokeWidth: 12,
                        backgroundColor: Colors.black.withValues(alpha: 0.05),
                        color: Colors.blueAccent,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          "${relay.currentSteps}",
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black87),
                        ),
                        Text(
                          "/ ${relay.targetSteps}",
                          style: const TextStyle(fontSize: 16, color: Colors.black38, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          "STEPS",
                          style: TextStyle(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (isMyTurn) ...[
                  const Text(
                    "You are the active link in the relay. Your steps are currently powering the team's progress.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: relay.currentSteps >= relay.targetSteps
                          ? () => _relayController.passRelay(widget.teamId)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.black.withValues(alpha: 0.05),
                        disabledForegroundColor: Colors.black26,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text(
                        "PASS RELAY TOKEN",
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    "WAITING FOR ${relay.currentOperatorName.toUpperCase()} TO COMPLETE THEIR SHIFT.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "RELAY SEQUENCE",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black45, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          // In a real app, we'd fetch the user names for the sequence
          ...relay.sequence.asMap().entries.map((entry) {
            final index = entry.key;
            final operatorId = entry.value;
            final bool isPast = index < relay.sequence.indexOf(relay.currentOperatorId);
            final bool isCurrent = operatorId == relay.currentOperatorId;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCurrent ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrent ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isPast ? Colors.greenAccent.withValues(alpha: 0.1) : (isCurrent ? Colors.blueAccent : Colors.black.withValues(alpha: 0.05)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isPast
                          ? const Icon(Icons.check, color: Colors.green, size: 16)
                          : Text(
                              "${index + 1}",
                              style: TextStyle(
                                color: isCurrent ? Colors.white : Colors.black38,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    operatorId == currentUid ? "YOU" : "OPERATOR ${index + 1}",
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w900 : FontWeight.bold,
                      color: isCurrent ? Colors.black87 : Colors.black38,
                    ),
                  ),
                  const Spacer(),
                  if (isCurrent)
                    const Icon(Icons.bolt_rounded, color: Colors.amber, size: 16),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showStartRelayDialog() {
    // Simplified: Just take the first few members or something
    // Real implementation would allow selecting sequence
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("START TEAM RELAY"),
        content: const Text("This will initialize a 3-stage relay. Each stage requires 5000 steps. Confirm?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              // Get team members... for now just use current user
              final currentUid = _firebaseService.auth.currentUser!.uid;
              final player = await _firebaseService.getPlayer(currentUid);
              
              await _relayController.startRelay(
                teamId: widget.teamId,
                sequence: [currentUid, "placeholder_1", "placeholder_2"],
                targetPerOperator: 5000,
                operatorName: player?.name ?? "Explorer",
              );
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text("START"),
          ),
        ],
      ),
    );
  }
}
