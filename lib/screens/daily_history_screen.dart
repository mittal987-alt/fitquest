import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/player_model.dart';
import '../services/firebase_service.dart';

class DailyHistoryScreen extends StatelessWidget {
  final PlayerModel player;

  const DailyHistoryScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    // Sort keys descending (most recent first)
    final sortedKeys = player.dailyHistory.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "OPERATIONAL LOGS",
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 1.5, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: sortedKeys.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: sortedKeys.length,
              itemBuilder: (context, index) {
                final dateKey = sortedKeys[index];
                final data = player.dailyHistory[dateKey] as Map<String, dynamic>;
                return _buildHistoryCard(dateKey, data);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.black.withValues(alpha: 0.05)),
          const SizedBox(height: 16),
          const Text(
            "NO ARCHIVED TELEMETRY",
            style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          const Text(
            "Complete a 24h cycle to log performance.",
            style: TextStyle(color: Colors.black26, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(String dateKey, Map<String, dynamic> data) {
    DateTime date = DateTime.parse(dateKey);
    int steps = data['steps'] ?? 0;
    int xp = data['xpGained'] ?? 0;
    List<dynamic> achievements = data['achievements'] ?? [];

    bool goalReached = steps >= player.dailyStepTarget;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(date).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.blueAccent, letterSpacing: 1),
                  ),
                  Text(
                    DateFormat('MMMM dd, yyyy').format(date),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
              if (goalReached)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text("TARGET MET", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statItem(Icons.directions_walk_rounded, "$steps", "STEPS", Colors.orange),
              const SizedBox(width: 24),
              _statItem(Icons.bolt_rounded, "+$xp", "XP GAINED", Colors.amber),
              const SizedBox(width: 24),
              _statItem(Icons.emoji_events_rounded, "${achievements.length}", "REWARDS", Colors.purple),
            ],
          ),
          if (achievements.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: achievements.map((a) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
                ),
                child: Text(
                  a.toString().toUpperCase(),
                  style: const TextStyle(color: Colors.purple, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87)),
          ],
        ),
        Text(label, style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
