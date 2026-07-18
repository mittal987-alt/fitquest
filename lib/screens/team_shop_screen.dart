import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_model.dart';
import '../models/activity_feed_model.dart';
import '../services/firebase_service.dart';
import '../config/gameplay_rules.dart';

class TeamShopScreen extends StatefulWidget {
  final String teamId;

  const TeamShopScreen({super.key, required this.teamId});

  @override
  State<TeamShopScreen> createState() => _TeamShopScreenState();
}

class _TeamShopScreenState extends State<TeamShopScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh every minute for the countdowns
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);

    return StreamBuilder<TeamModel?>(
      stream: firebaseService.getTeamStream(widget.teamId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1117),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final team = snapshot.data!;

        return Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              "TEAM ARMORY",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.withValues(alpha: 0.2), Colors.amber.withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "${team.teamCurrency}",
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: "ARMORY"),
                    Tab(text: "HISTORY"),
                  ],
                  indicatorColor: Colors.amber,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text(
                            "ACTIVE TACTICAL MODIFIERS",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (team.activeTeamBuffs.isEmpty)
                            const Text(
                              "No active buffs. Purchase one below to support your squad.",
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            )
                          else
                            ...team.activeTeamBuffs.entries.map((entry) {
                              final buff = GameplayRules.teamBuffPool.firstWhere(
                                (b) => b['id'] == entry.key,
                                orElse: () => {"name": "Unknown Buff"},
                              );
                              final timeLeft = entry.value.difference(DateTime.now());
                              if (timeLeft.isNegative) return const SizedBox.shrink();
                              return _buildActiveBuffItem(buff['name'], timeLeft);
                            }),
                          const SizedBox(height: 32),
                          const Text(
                            "AVAILABLE UPGRADES",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...GameplayRules.teamBuffPool.map((buff) => _buildShopItem(context, buff, team)),
                        ],
                      ),
                      _buildHistoryTab(firebaseService, widget.teamId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveBuffItem(String name, Duration timeLeft) {
    String timeStr = timeLeft.inHours > 0 
        ? "${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m remaining"
        : "${timeLeft.inMinutes}m remaining";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.withValues(alpha: 0.15), Colors.blueAccent.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItem(BuildContext context, Map<String, dynamic> buff, TeamModel team) {
    final bool canAfford = team.teamCurrency >= buff['cost'];
    final Color itemColor = _getBuffColor(buff['type']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: itemColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: itemColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: itemColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getBuffIcon(buff['type']), color: itemColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            buff['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Duration: ${buff['duration'].inHours} Hours",
                            style: TextStyle(color: itemColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "${buff['cost']}",
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  buff['description'],
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: ElevatedButton(
              onPressed: canAfford ? () => _purchaseBuff(context, buff, team) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: itemColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white10,
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                canAfford ? "ACTIVATE MODIFIER" : "INSUFFICIENT FUNDS",
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _purchaseBuff(BuildContext context, Map<String, dynamic> buff, TeamModel team) async {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await firebaseService.purchaseTeamBuff(team.id, buff);
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${buff['name']} activated for the whole team!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to purchase: $e"), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildHistoryTab(FirebaseService firebaseService, String teamId) {
    return StreamBuilder<List<ActivityFeedModel>>(
      stream: firebaseService.getTeamBuffHistory(teamId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final history = snapshot.data!;
        if (history.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded, color: Colors.white10, size: 64),
                SizedBox(height: 16),
                Text(
                  "No activation history found.",
                  style: TextStyle(color: Colors.white38),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final event = history[index];
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.greenAccent.withValues(alpha: 0.1),
                  child: const Icon(Icons.history_rounded, color: Colors.greenAccent, size: 20),
                ),
                title: Text(
                  event.itemId ?? "Unknown Buff",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  event.timestamp != null 
                      ? "${event.timestamp!.day}/${event.timestamp!.month} ${event.timestamp!.hour}:${event.timestamp!.minute.toString().padLeft(2, '0')}"
                      : "Unknown date",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 16),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getBuffIcon(String type) {
    switch (type) {
      case 'stamina_regen': return Icons.bolt_rounded;
      case 'raid_damage': return Icons.whatshot_rounded;
      case 'territory_xp': return Icons.terrain_rounded;
      default: return Icons.extension_rounded;
    }
  }

  Color _getBuffColor(String type) {
    switch (type) {
      case 'stamina_regen': return Colors.blueAccent;
      case 'raid_damage': return Colors.redAccent;
      case 'territory_xp': return Colors.greenAccent;
      default: return Colors.purpleAccent;
    }
  }
}
