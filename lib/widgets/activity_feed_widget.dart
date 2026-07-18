import 'package:flutter/material.dart';
import '../models/activity_feed_model.dart';

class ActivityFeedWidget extends StatelessWidget {
  final List<ActivityFeedModel> activities;

  const ActivityFeedWidget({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: activities.map((activity) => _buildFeedItem(activity)).toList(),
    );
  }

  Widget _buildFeedItem(ActivityFeedModel activity) {
    IconData icon;
    Color color;

    switch (activity.type) {
      case ActivityType.capture:
        icon = Icons.map_rounded;
        color = Colors.cyanAccent;
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
        color = Colors.blueAccent;
        break;
      case ActivityType.challengeCompleted:
        icon = Icons.verified_rounded;
        color = Colors.greenAccent;
        break;
      case ActivityType.rewardClaimed:
      case ActivityType.teamChallengeReward:
        icon = Icons.redeem_rounded;
        color = Colors.purpleAccent;
        break;
      case ActivityType.teamBuffActivated:
        icon = Icons.bolt_rounded;
        color = Colors.yellowAccent;
        break;
    }

    String displayMessage = activity.message;
    if (displayMessage.isEmpty) {
      switch (activity.type) {
        case ActivityType.challengeStarted:
          displayMessage = "started challenge: ${activity.itemId}";
          break;
        case ActivityType.challengeCompleted:
          displayMessage = "completed challenge: ${activity.itemId}";
          break;
        case ActivityType.rewardClaimed:
          displayMessage = "claimed rewards for: ${activity.itemId}";
          break;
        case ActivityType.teamBuffActivated:
          displayMessage = "activated team buff: ${activity.itemId}";
          break;
        default:
          displayMessage = "";
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    children: [
                      if (activity.playerName != null)
                        TextSpan(
                          text: activity.playerName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      TextSpan(text: " $displayMessage"),
                    ],
                  ),
                ),
                if (activity.timestamp != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(activity.timestamp!),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }
}
