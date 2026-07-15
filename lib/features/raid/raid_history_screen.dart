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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
                  Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.black.withValues(alpha: 0.05)),
                  const SizedBox(height: 24),
                  const Text(
                    "NO RECORDED ENGAGEMENTS",
                    style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Deploy on a team raid to begin archives.",
                    style: TextStyle(color: Colors.black26, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          final logs = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    final bool isSuccess = log.isSuccess;
    final Color statusColor = isSuccess ? Colors.green : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
                    DateFormat('EEEE').format(log.timestamp).toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 1.5),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy | HH:mm').format(log.timestamp),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black38),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isSuccess ? "MISSION SUCCESS" : "MISSION FAILED",
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            log.bossName.replaceAll('_', ' ').toUpperCase(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.flash_on_rounded, size: 14, color: Colors.orangeAccent),
              const SizedBox(width: 6),
              Text(
                "FINAL STRIKE: ${log.victorName.toUpperCase()}",
                style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, thickness: 1),
          ),
          Row(
            children: [
              _statDetail("TOTAL DAMAGE", log.totalDamage.toStringAsFixed(0), Icons.analytics_outlined, Colors.orangeAccent),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("LOOT SECURED", style: TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  if (log.lootDrops.isEmpty)
                    const Text("NONE", style: TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold))
                  else
                    Wrap(
                      spacing: 6,
                      children: log.lootDrops.take(3).map((loot) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          loot.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.w900),
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

  Widget _statDetail(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
            ),
          ],
        ),
      ],
    );
  }
}
