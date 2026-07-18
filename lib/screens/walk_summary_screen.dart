import 'dart:io';
import 'package:flutter/material.dart';
import '../models/walk_session_model.dart';
import '../models/player_model.dart';
import '../services/firebase_service.dart';

class WalkSummaryScreen extends StatelessWidget {
  final WalkSessionModel session;
  final PlayerModel? player;

  const WalkSummaryScreen({super.key, required this.session, this.player});

  static const Color _kBgColor = Color(0xFF0D1117);
  static const Color _kPrimaryPurple = Color(0xFF8E2DE2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      "MISSION COMPLETE",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Text(
                      "WELL DONE, STRIDER",
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "${session.steps} STEPS",
                      style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 32),
                    _buildStatsRow(),
                    const SizedBox(height: 40),
                    if (session.memories.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "WALK MEMORIES",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMemoriesGrid(),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (player?.isInTeam ?? false) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _shareToTeam(context),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text("SHARE TO TEAM CHAT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.cyanAccent,
                          side: const BorderSide(color: Colors.cyanAccent, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("RETURN TO BASE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareToTeam(BuildContext context) async {
    if (player == null || !player!.isInTeam || player!.teamId == null) return;

    final service = FirebaseService();
    final kcal = (session.steps * 0.04).toInt();
    final duration = session.endTime.difference(session.startTime).inMinutes;
    
    final message = "🚀 MISSION COMPLETE!\n"
        "Captured ${session.steps} steps ($kcal kcal) over ${session.distanceKm.toStringAsFixed(2)} km.\n"
        "Duration: $duration mins.";

    try {
      await service.sendTeamChatMessage(
        player!.teamId!,
        player!.uid,
        player!.name,
        message,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("RESULTS SHARED TO TEAM CHAT!"),
            backgroundColor: Colors.cyan,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to share: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statItem(session.distanceKm.toStringAsFixed(2), "KM", Icons.straighten_rounded),
        _statItem("${(session.steps * 0.04).toInt()}", "KCAL", Icons.local_fire_department_rounded),
        _statItem("${session.endTime.difference(session.startTime).inMinutes}", "MINS", Icons.timer_rounded),
      ],
    );
  }

  Widget _statItem(String value, String unit, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: _kPrimaryPurple, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMemoriesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: session.memories.length,
      itemBuilder: (context, index) {
        final memory = session.memories[index];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(memory.imageUrl), fit: BoxFit.cover),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    child: Text(
                      memory.caption,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
