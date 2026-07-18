import 'package:flutter/material.dart';
import '../../controller/raid_controller.dart';

class RaidResultScreen extends StatelessWidget {
  final List<RaidParticipant> participants;
  final String teamName;
  final double totalDamage;
  final String bossName;

  const RaidResultScreen({
    super.key,
    required this.participants,
    required this.teamName,
    required this.totalDamage,
    required this.bossName,
  });

  @override
  Widget build(BuildContext context) {
    // Sort for Standard MVP (Total Damage)
    final sortedByDamage = List<RaidParticipant>.from(participants)
      ..sort((a, b) => b.damageContributed.compareTo(a.damageContributed));

    // Sort for Ghost Strider MVP (Ghost Damage)
    final sortedByGhostDamage = List<RaidParticipant>.from(participants)
      ..sort((a, b) => b.ghostDamageContributed.compareTo(a.ghostDamageContributed));

    final mvp = sortedByDamage.isNotEmpty ? sortedByDamage.first : null;
    final ghostMvp = sortedByGhostDamage.isNotEmpty && sortedByGhostDamage.first.ghostDamageContributed > 0 
        ? sortedByGhostDamage.first 
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                "RAID SUCCESSFUL",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.greenAccent,
                  shadows: [
                    Shadow(color: Colors.greenAccent.withValues(alpha: 0.5), blurRadius: 10)
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.greenAccent.withValues(alpha: 0.2), Colors.black],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.greenAccent.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headerText("BATTLE REPORT: $bossName"),
                  const SizedBox(height: 8),
                  Text(
                    "SQUAD: ${teamName.toUpperCase()}",
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),

                  // MVP Highlights
                  Row(
                    children: [
                      if (mvp != null)
                        Expanded(child: _mvpCard("DAMAGE MVP", mvp.displayName, mvp.damageContributed.toInt().toString(), Icons.workspace_premium_rounded, Colors.orangeAccent)),
                      if (ghostMvp != null) ...[
                        const SizedBox(width: 16),
                        Expanded(child: _mvpCard("GHOST STRIDER", ghostMvp.displayName, ghostMvp.ghostDamageContributed.toInt().toString(), Icons.auto_awesome, Colors.cyanAccent)),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  _headerText("PARTICIPANT BREAKDOWN"),
                  const SizedBox(height: 16),
                  
                  // Participant List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedByDamage.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final p = sortedByDamage[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.white10,
                          child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(p.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("${p.stepsContributed} STEPS", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("${p.damageContributed.toInt()} DMG", style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w900)),
                            if (p.ghostDamageContributed > 0)
                              Text("+${p.ghostDamageContributed.toInt()} GHOST", style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                  _headerText("LOOT ACQUIRED"),
                  const SizedBox(height: 16),
                  
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _lootItem("500 XP", Icons.bolt_rounded, Colors.blueAccent),
                      _lootItem("10 TOKENS", Icons.token_rounded, Colors.amber),
                      _lootItem("POWER CORE", Icons.settings_input_component_rounded, Colors.cyanAccent),
                      _lootItem("CIRCUITRY", Icons.memory_rounded, Colors.purpleAccent),
                    ],
                  ),

                  const SizedBox(height: 60),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("RETURN TO BASE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
    );
  }

  Widget _mvpCard(String title, String name, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 4),
          Text("$value DMG", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _lootItem(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
