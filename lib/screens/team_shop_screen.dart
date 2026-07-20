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
    final theme = Theme.of(context);

    return StreamBuilder<TeamModel?>(
      stream: firebaseService.getTeamStream(widget.teamId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final team = snapshot.data!;

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              "TEAM ARMORY",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.secondary.withValues(alpha: 0.2), theme.colorScheme.secondary.withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.stars_rounded, color: theme.colorScheme.secondary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "${team.teamCurrency}",
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
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
                TabBar(
                  tabs: const [
                    Tab(text: "ARMORY"),
                    Tab(text: "HISTORY"),
                  ],
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.onSurface,
                  unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            "ACTIVE TACTICAL MODIFIERS",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (team.activeTeamBuffs.isEmpty)
                            Text(
                              "No active buffs. Purchase one below to support your squad.",
                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 13),
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
                          Text(
                            "AVAILABLE UPGRADES",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
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
    final theme = Theme.of(context);
    String timeStr = timeLeft.inHours > 0 
        ? "${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m remaining"
        : "${timeLeft.inMinutes}m remaining";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary.withValues(alpha: 0.15), theme.colorScheme.primary.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                ),
                Text(
                  timeStr,
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
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
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
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
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
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
                        color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, color: theme.colorScheme.secondary, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "${buff['cost']}",
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
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
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: ElevatedButton(
              onPressed: canAfford ? () => _purchaseBuff(context, buff, team) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: itemColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
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
        final theme = Theme.of(context);
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${buff['name']} activated for the whole team!"),
            backgroundColor: theme.colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final theme = Theme.of(context);
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to purchase: $e"), 
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildHistoryTab(FirebaseService firebaseService, String teamId) {
    final theme = Theme.of(context);
    return StreamBuilder<List<ActivityFeedModel>>(
      stream: firebaseService.getTeamBuffHistory(teamId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final history = snapshot.data!;
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.1), size: 64),
                const SizedBox(height: 16),
                Text(
                  "No activation history found.",
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
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
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.history_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                title: Text(
                  event.itemId ?? "Unknown Buff",
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  event.timestamp != null 
                      ? "${event.timestamp!.day}/${event.timestamp!.month} ${event.timestamp!.hour}:${event.timestamp!.minute.toString().padLeft(2, '0')}"
                      : "Unknown date",
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                trailing: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary, size: 16),
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
