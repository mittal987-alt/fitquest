import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:confetti/confetti.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'team_screen.dart';
import 'profile_screen.dart';
import 'activity_screen.dart';
import '../services/pedometer_service.dart';
import '../services/step_sync_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/daily_login_service.dart';
import '../controller/raid_controller.dart';
import '../models/player_model.dart';
import '../models/achievement_model.dart';
import '../models/activity_feed_model.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;
  String? currentTeamId;
  StreamSubscription<PlayerModel?>? _playerSubscription;
  late ConfettiController _confettiController;

  final PedometerService pedometerService = PedometerService();
  final StepSyncService stepSyncService = StepSyncService();

  final List<Widget> pages = [
    const HomeScreen(),
    const MapScreen(),
    const ActivityScreen(),
    const TeamScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await [
      Permission.activityRecognition,
      Permission.locationWhenInUse,
    ].request();

    if (!mounted) return;
    _setupTeamNotifications();

    // Trigger daily login check
    DailyLoginService.checkLogin(context);

    // Foreground-only service triggers
    stepSyncService.startTracking();
  }

  StreamSubscription<List<ActivityFeedModel>>? _teamActivitySubscription;

  void _setupTeamNotifications() {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    final uid = firebaseService.auth.currentUser?.uid;

    // Listen for FCM messages directly when in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        notificationService.showLocalNotification(
          title: message.notification!.title ?? "TACTICAL INBOUND",
          body: message.notification!.body ?? "",
        );
      }
    });

    if (uid != null) {
      _playerSubscription = firebaseService.getPlayerStream(uid).listen((player) async {
        if (!mounted) return;

        if (player == null) {
          debugPrint("PROFILE MISSING: Attempting auto-initialization for $uid");
          await firebaseService.ensurePlayerProfileExists(
            uid,
            firebaseService.auth.currentUser?.email ?? "unknown@fitquest.io",
            "Player ${uid.substring(0, 5)}",
          );
          return;
        }

        // --- RPG ACHIEVEMENT & LEVEL MONITORING ---
        _checkRpgMilestones(player);

        final notificationService = Provider.of<NotificationService>(context, listen: false);
        stepSyncService.updateConfig(player);

        if (player.teamId != currentTeamId) {
          if (currentTeamId != null) {
            notificationService.unsubscribeFromTeam(currentTeamId!);
            _teamActivitySubscription?.cancel();
          }
          if (player.teamId != null) {
            notificationService.subscribeToTeam(player.teamId!);
            
            // Listen to team activity feed for push-like notifications
            _teamActivitySubscription = firebaseService.getTeamActivityFeed(player.teamId!).listen((feed) {
              if (feed.isNotEmpty) {
                final latest = feed.first;
                // Only process very recent events
                if (latest.timestamp != null && 
                    DateTime.now().difference(latest.timestamp!).inSeconds < 10) {
                  notificationService.processActivityFeedEvent(latest);
                }
              }
            });

            if (mounted) {
              context.read<RaidController>().initTeamRaid(player.teamId!);
            }
          }

          setState(() {
            currentTeamId = player.teamId;
          });
        }
      });
    }
  }

  void _checkRpgMilestones(PlayerModel player) {

    // 1. Check Level Up
    if (currentLevel != null && player.level > currentLevel!) {
      _showLevelUpDialog(player.level);
    }
    currentLevel = player.level;

    // 2. Check Achievement Unlocks
    final newlyUnlocked = player.unlockedAchievements
        .where((id) => !(previousAchievements?.contains(id) ?? true))
        .toList();

    for (var achievementId in newlyUnlocked) {
      _showAchievementPopup(achievementId);
    }
    previousAchievements = List.from(player.unlockedAchievements);
  }

  int? currentLevel;
  List<String>? previousAchievements;

  void _showLevelUpDialog(int level) {
    _confettiController.play();
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colorScheme.primary, width: 2),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, color: colorScheme.primary, size: 80),
              const SizedBox(height: 24),
              Text(
                "LEVEL UP", 
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                "RANK: ${FirebaseService().getRankTitle(level)}", 
                style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                "You have reached Level $level!", 
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary, 
                  foregroundColor: colorScheme.onPrimary, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("CONTINUE MISSION"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAchievementPopup(String id) {
    final achievement = kGlobalAchievements.firstWhere((a) => a.id == id, orElse: () => kGlobalAchievements.first);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: achievement.color, width: 2),
                boxShadow: [BoxShadow(color: achievement.color.withValues(alpha: 0.2), blurRadius: 12)],
              ),
              child: Row(
                children: [
                  Icon(achievement.icon, color: achievement.color, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ACHIEVEMENT UNLOCKED", 
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          achievement.title.toUpperCase(), 
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    _teamActivitySubscription?.cancel();
    _confettiController.dispose();
    stepSyncService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Stack(
      children: [
        Scaffold(
          backgroundColor: colorScheme.surface,
          body: IndexedStack(
            index: currentIndex,
            children: pages,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
            ),
            child: BottomAppBar(
              height: 85,
              padding: EdgeInsets.zero,
              notchMargin: 12,
              shape: const CircularNotchedRectangle(),
              color: colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_rounded, "HQ", colorScheme),
                  _buildNavItem(1, Icons.map_rounded, "MAP", colorScheme),
                  const SizedBox(width: 48),
                  _buildNavItem(3, Icons.groups_rounded, "TEAMS", colorScheme),
                  _buildNavItem(4, Icons.person_rounded, "PROFILE", colorScheme),
                ],
              ),
            ),
          ),
          floatingActionButton: Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () => setState(() => currentIndex = 2),
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: const CircleBorder(),
              child: Icon(Icons.directions_walk_rounded, color: colorScheme.onPrimary, size: 36),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.purple, Colors.blue, Colors.orange, Colors.green],
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, ColorScheme colorScheme) {
    final bool isSelected = currentIndex == index;
    return InkResponse(
      onTap: () => setState(() => currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            size: 26,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
