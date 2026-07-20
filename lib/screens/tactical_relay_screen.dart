import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/tactical_relay_controller.dart';
import '../models/tactical_relay_model.dart';
import '../services/firebase_service.dart';

class TacticalRelayScreen extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TacticalRelayScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<TacticalRelayScreen> createState() => _TacticalRelayScreenState();
}

class _TacticalRelayScreenState extends State<TacticalRelayScreen> {
  final TacticalRelayController _challengeController = TacticalRelayController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isProcessing = false;
  final Map<String, String> _nameCache = {};

  void _ensureNamesCached(List<String> uids) {
    bool hasMissing = uids.any((uid) => !_nameCache.containsKey(uid));
    if (hasMissing) {
      _fetchNames(uids);
    }
  }

  Future<void> _fetchNames(List<String> uids) async {
    for (String uid in uids) {
      if (!_nameCache.containsKey(uid)) {
        final player = await _firebaseService.getPlayer(uid);
        if (mounted) {
          setState(() {
            _nameCache[uid] = player?.name ?? "OPERATOR";
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "${widget.teamName.toUpperCase()} TACTICAL RELAY",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 16,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: StreamBuilder<TacticalRelayModel?>(
        stream: _challengeController.getTeamRelay(widget.teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
          }

          final challenge = snapshot.data;

          if (challenge == null || !challenge.isActive) {
            return _buildNoActiveChallenge(theme);
          }

          return _buildActiveChallenge(challenge, theme);
        },
      ),
    );
  }

  Widget _buildNoActiveChallenge(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sync_alt_rounded, size: 80, color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          Text(
            "NO ACTIVE TACTICAL RELAY",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Start a relay to coordinate step goals with your team and earn massive XP & Credit rewards.",
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ElevatedButton.icon(
              onPressed: () => _showStartChallengeDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: theme.colorScheme.onPrimary,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                "START TACTICAL RELAY",
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChallenge(TacticalRelayModel challenge, ThemeData theme) {
    final currentUid = _firebaseService.auth.currentUser?.uid;
    if (currentUid == null) {
      return Center(
        child: Text("NOT LOGGED IN", style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.bold)),
      );
    }
    final bool isMyTurn = challenge.currentPlayerId == currentUid;
    final int currentPlayerIndex = challenge.sequence.indexOf(challenge.currentPlayerId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isMyTurn ? theme.colorScheme.primary.withValues(alpha: 0.3) : theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CURRENT OPERATOR",
                          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isMyTurn ? "YOU (ACTIVE)" : challenge.currentPlayerName.toUpperCase(),
                          style: TextStyle(
                            color: isMyTurn ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.fitness_center_rounded, color: theme.colorScheme.primary, size: 32),
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
                        value: challenge.progress,
                        strokeWidth: 12,
                        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        color: theme.colorScheme.primary,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          "${challenge.currentSteps}",
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
                        ),
                        Text(
                          "/ ${challenge.targetSteps}",
                          style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "STEPS",
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.2), fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (isMyTurn) ...[
                  Text(
                    "You are the active operator in the relay. Your steps are currently contributing to the team's progress.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: challenge.currentSteps >= challenge.targetSteps ? LinearGradient(
                        colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ) : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: (challenge.currentSteps >= challenge.targetSteps && !_isProcessing)
                          ? () async {
                              setState(() => _isProcessing = true);
                              await HapticFeedback.heavyImpact();
                              try {
                                await _challengeController.passRelayToken(widget.teamId);
                              } finally {
                                if (mounted) setState(() => _isProcessing = false);
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: _isProcessing 
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                        : const Icon(Icons.send_rounded),
                      label: Text(
                        _isProcessing ? "PROCESSING..." : "PASS RELAY TOKEN",
                        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    "WAITING FOR ${challenge.currentPlayerName.toUpperCase()} TO FINISH THEIR TURN.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.2), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "RELAY SEQUENCE",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              _ensureNamesCached(challenge.sequence);

              return Column(
                children: challenge.sequence.asMap().entries.map((entry) {
                  final index = entry.key;
                  final playerId = entry.value;
                  final bool isPast = index < currentPlayerIndex;
                  final bool isCurrent = playerId == challenge.currentPlayerId;
                  final String displayName = _nameCache[playerId] ?? "OPERATOR ${index + 1}";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCurrent ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent ? theme.colorScheme.primary.withValues(alpha: 0.2) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isPast ? Colors.greenAccent.withValues(alpha: 0.1) : (isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.05)),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isPast
                                ? const Icon(Icons.check, color: Colors.greenAccent, size: 16)
                                : Text(
                              "${index + 1}",
                              style: TextStyle(
                                color: isCurrent ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          playerId == currentUid ? "YOU" : displayName.toUpperCase(),
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.w900 : FontWeight.bold,
                            color: isCurrent ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          ),
                        ),
                        const Spacer(),
                        if (isCurrent)
                          const Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 16),
                        if (isPast)
                          const Text(
                            "COMPLETE",
                            style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showStartChallengeDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("START TACTICAL RELAY", style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
        content: Text(
          "This will start a multi-stage relay. Each operator must complete their step goal before passing the relay token to the next team member.",
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.bold)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: theme.colorScheme.onPrimary,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                await HapticFeedback.mediumImpact();

                try {
                  // Fetch all team members to build the sequence
                  final membersSnapshot = await _firebaseService.firestore
                      .collection("players")
                      .where("teamId", isEqualTo: widget.teamId)
                      .get();

                  if (membersSnapshot.docs.isEmpty) return;

                  final List<String> sequence = membersSnapshot.docs.map((doc) => doc.id).toList();
                  // Ensure current user is first in sequence for testing/starting
                  final currentUid = _firebaseService.auth.currentUser!.uid;
                  sequence.remove(currentUid);
                  sequence.insert(0, currentUid);

                  final firstPlayer = await _firebaseService.getPlayer(currentUid);

                  await _challengeController.startRelay(
                    teamId: widget.teamId,
                    sequence: sequence,
                    targetPerPlayer: 5000,
                    playerName: firstPlayer?.name ?? "Operator",
                  );

                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text("TACTICAL RELAY STARTED"),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text("ERROR STARTING RELAY: $e"),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              },
              child: const Text("START", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}