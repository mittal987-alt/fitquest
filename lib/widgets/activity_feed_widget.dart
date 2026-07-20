import 'package:flutter/material.dart';
import '../models/activity_feed_model.dart';
import '../screens/achievements_screen.dart';
import '../screens/activity_screen.dart';
import '../screens/tactical_relay_screen.dart';

class ActivityFeedWidget extends StatelessWidget {
  final List<ActivityFeedModel> activities;

  const ActivityFeedWidget({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(
                Icons.history_rounded, 
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1), 
                size: 48
              ),
              const SizedBox(height: 16),
              Text(
                "NO RECENT ACTIVITY",
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort activities by timestamp descending
    final sortedActivities = List<ActivityFeedModel>.from(activities)
      ..sort((a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));

    final List<Widget> items = [];
    String? lastLabel;
    int globalIndex = 0;

    for (var activity in sortedActivities) {
      final label = _getDateLabel(activity.timestamp);
      if (label != lastLabel) {
        lastLabel = label;
        items.add(_buildGroupHeader(context, label));
      }

      final index = globalIndex++;
      items.add(
        TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 400 + (index * 100).clamp(0, 600)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutQuint,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _buildFeedItem(context, activity),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  String _getDateLabel(DateTime? timestamp) {
    if (timestamp == null) return "RECENT";
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (date.isAtSameMomentAs(today)) return "TODAY";
    if (date.isAtSameMomentAs(yesterday)) return "YESTERDAY";
    if (now.difference(date).inDays < 7) return "THIS WEEK";
    return "EARLIER";
  }

  Widget _buildGroupHeader(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedItem(BuildContext context, ActivityFeedModel activity) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    IconData icon = Icons.notifications_rounded;
    Color color = Colors.blueGrey;

    switch (activity.type) {
      case ActivityType.capture:
        icon = Icons.map_rounded;
        color = colorScheme.primary;
        break;
      case ActivityType.teamRank:
        icon = Icons.trending_up_rounded;
        color = Colors.orangeAccent;
        break;
      case ActivityType.achievement:
        icon = Icons.emoji_events_rounded;
        color = Colors.amberAccent;
        break;
      case ActivityType.steps:
        icon = Icons.directions_walk_rounded;
        color = Colors.greenAccent;
        break;
      case ActivityType.challengeStarted:
        icon = Icons.assignment_rounded;
        color = colorScheme.secondary;
        break;
      case ActivityType.challengeCompleted:
        icon = Icons.verified_rounded;
        color = Colors.greenAccent;
        break;
      case ActivityType.rewardClaimed:
      case ActivityType.teamChallengeReward:
        icon = Icons.redeem_rounded;
        color = colorScheme.tertiary;
        break;
      case ActivityType.teamBuffActivated:
        icon = Icons.bolt_rounded;
        color = Colors.yellowAccent;
        break;
      case ActivityType.relayStarted:
        icon = Icons.timer_outlined;
        color = colorScheme.secondary;
        break;
      case ActivityType.relayTransferred:
        icon = Icons.swap_calls_rounded;
        color = Colors.orangeAccent;
        break;
      case ActivityType.relayCompleted:
        icon = Icons.flag_rounded;
        color = Colors.greenAccent;
        break;
      case ActivityType.walkSessionStarted:
        icon = Icons.play_circle_fill_rounded;
        color = colorScheme.primary;
        break;
      case ActivityType.walkSessionEnded:
        icon = Icons.stop_circle_rounded;
        color = colorScheme.onSurfaceVariant;
        break;
      case ActivityType.trainingSessionStarted:
        icon = Icons.fitness_center_rounded;
        color = colorScheme.tertiary;
        break;
      case ActivityType.trainingSessionEnded:
        icon = Icons.check_circle_outline_rounded;
        color = Colors.greenAccent;
        break;
    }

    String displayMessage = activity.message;
    if (displayMessage.isEmpty) {
      switch (activity.type) {
        case ActivityType.challengeStarted:
          displayMessage = "initiated challenge: [${activity.itemId ?? 'UNKNOWN'}]";
          break;
        case ActivityType.challengeCompleted:
          displayMessage = "completed challenge: [${activity.itemId ?? 'UNKNOWN'}]";
          break;
        case ActivityType.rewardClaimed:
          displayMessage = "claimed rewards for: [${activity.itemId ?? 'UNKNOWN'}]";
          break;
        case ActivityType.teamBuffActivated:
          displayMessage = "activated team buff: [${activity.itemId ?? 'UNKNOWN'}]";
          break;
        case ActivityType.capture:
          displayMessage = "captured territory: [${activity.itemId ?? 'UNKNOWN'}]";
          break;
        case ActivityType.achievement:
          displayMessage = "unlocked achievement: [${activity.itemId ?? 'UNKNOWN'}]";
          break;
        case ActivityType.teamRank:
          displayMessage = "reached team rank: [${activity.itemId ?? 'UNKNOWN'}]";
          break;
        case ActivityType.teamChallengeReward:
          displayMessage = "earned team challenge rewards";
          break;
        case ActivityType.steps:
          displayMessage = "reached a new step milestone";
          break;
        case ActivityType.relayStarted:
          displayMessage = "started the Tactical Relay";
          break;
        case ActivityType.relayTransferred:
          displayMessage = "transferred the relay baton";
          break;
        case ActivityType.relayCompleted:
          displayMessage = "finished the Tactical Relay";
          break;
        case ActivityType.walkSessionStarted:
          displayMessage = "started a reconnaissance walk";
          break;
        case ActivityType.walkSessionEnded:
          displayMessage = "completed their mission";
          break;
        case ActivityType.trainingSessionStarted:
          displayMessage = "initiated a training protocol";
          break;
        case ActivityType.trainingSessionEnded:
          displayMessage = "completed a training session";
          break;
      }
    }

    final isPriority = activity.type == ActivityType.relayStarted ||
                       activity.type == ActivityType.relayTransferred ||
                       activity.type == ActivityType.relayCompleted ||
                       activity.type == ActivityType.achievement ||
                       activity.type == ActivityType.walkSessionStarted ||
                       activity.type == ActivityType.trainingSessionStarted;

    final isVeryRecent = activity.timestamp != null && 
                         DateTime.now().difference(activity.timestamp!).inSeconds < 60;

    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: () => _handleActivityTap(context, activity),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isPriority 
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)) 
                  : (isDark ? const Color(0xFF161B22) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPriority 
                    ? color.withValues(alpha: 0.3) 
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                width: isPriority ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isPriority ? 0.08 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        boxShadow: [
                          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1),
                        ],
                      ),
                    ),
                  ),
                  if (isVeryRecent)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildLiveBadge(),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _buildIconContainer(icon, color, isPriority),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  children: [
                                    if (activity.playerName != null)
                                      TextSpan(
                                        text: activity.playerName!.toUpperCase(),
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ..._buildStyledMessage(displayMessage, activity.itemId, color, activity.playerName != null),
                                  ],
                                ),
                              ),
                              if (activity.timestamp != null) ...[
                                const SizedBox(height: 8),
                                _buildTimestamp(context, activity.timestamp!),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  void _handleActivityTap(BuildContext context, ActivityFeedModel activity) {
    switch (activity.type) {
      case ActivityType.relayStarted:
      case ActivityType.relayTransferred:
      case ActivityType.relayCompleted:
        if (activity.teamId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TacticalRelayScreen(
                teamId: activity.teamId!,
                teamName: "Team", // We don't have the team name here, using placeholder
              ),
            ),
          );
        }
        break;
      case ActivityType.walkSessionStarted:
      case ActivityType.walkSessionEnded:
      case ActivityType.trainingSessionStarted:
      case ActivityType.trainingSessionEnded:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ActivityScreen(),
          ),
        );
        break;
      case ActivityType.achievement:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AchievementsScreen(),
          ),
        );
        break;
      default:
        // Generic tap handling
        break;
    }
  }

  Widget _buildIconContainer(IconData icon, Color color, bool isPriority) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
        shadows: [
          Shadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          const Text(
            "LIVE",
            style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildStyledMessage(String message, String? itemId, Color themeColor, bool hasPlayerName) {
    final prefix = hasPlayerName ? " " : "";
    if (itemId == null || !message.contains(itemId)) {
      return [TextSpan(text: "$prefix$message")];
    }

    final parts = message.split(itemId);
    return [
      TextSpan(text: "$prefix${parts[0]}"),
      TextSpan(
        text: itemId,
        style: TextStyle(
          color: themeColor,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          decorationColor: themeColor.withValues(alpha: 0.3),
        ),
      ),
      if (parts.length > 1) TextSpan(text: parts[1]),
    ];
  }

  Widget _buildTimestamp(BuildContext context, DateTime timestamp) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(Icons.access_time_rounded, size: 10, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 4),
        Text(
          _formatTimestamp(timestamp).toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) return "JUST NOW";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }
}
