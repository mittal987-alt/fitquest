import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/raid_log_model.dart';

class RaidHistoryScreen extends StatelessWidget {
  final String teamId;
  final FirebaseService _firebaseService = FirebaseService();

  RaidHistoryScreen({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "MISSION ARCHIVES",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<List<RaidLog>>(
        stream: _firebaseService.getRaidHistory(teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.black.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  const Text(
                    "NO RECORDED VICTORIES",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 1),
                  ),
                ],
              ),
            );
          }

          final logs = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _buildRaidLogCard(log);
            },
          );
        },
      ),
    );
  }

  Widget _buildRaidLogCard(RaidLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM dd, yyyy | HH:mm').format(log.timestamp).toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38, letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "SUCCESS",
                  style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            log.bossName.toUpperCase(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            "Final Strike: ${log.victorName}",
            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24, thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TOTAL DAMAGE dealt", style: TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    log.totalDamage.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.orangeAccent),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("LOOT SECURED", style: TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 4,
                    children: log.lootDrops.map((loot) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        loot.replaceAll('_', ' '),
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
