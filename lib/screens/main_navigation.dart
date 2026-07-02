import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'leaderboard_screen.dart';
import 'team_screen.dart';
import 'profile_screen.dart';
import '../services/pedometer_service.dart';
import '../services/step_sync_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../models/player_model.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;
  String? currentTeamId;
  StreamSubscription<PlayerModel?>? _playerSubscription;

  final PedometerService pedometerService = PedometerService();
  final StepSyncService stepSyncService = StepSyncService();

  final List<Widget> pages = [
    const HomeScreen(),
    const MapScreen(),
    const LeaderboardScreen(),
    const TeamScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await [
      Permission.activityRecognition,
      Permission.locationWhenInUse,
    ].request();

    if (!mounted) return;
    _setupTeamNotifications();

    // Foreground-only service triggers
    stepSyncService.startTracking();
  }

  void _setupTeamNotifications() {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final uid = firebaseService.auth.currentUser?.uid;

    if (uid != null) {
      _playerSubscription = firebaseService.getPlayerStream(uid).listen((player) {
        if (!mounted || player == null) return;

        final notificationService = Provider.of<NotificationService>(context, listen: false);
        stepSyncService.updateConfig(player);

        if (player.teamId != currentTeamId) {
          if (currentTeamId != null) {
            notificationService.unsubscribeFromTeam(currentTeamId!);
          }
          if (player.teamId != null) {
            notificationService.subscribeToTeam(player.teamId!);
          }

          setState(() {
            currentTeamId = player.teamId;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    stepSyncService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.05), width: 1.5)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w900);
              }
              return const TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Colors.white);
              }
              return const IconThemeData(color: Colors.black38);
            }),
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            height: 72,
            backgroundColor: Colors.white,
            indicatorColor: Colors.blueAccent,
            elevation: 0,
            onDestinationSelected: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: "HQ"),
              NavigationDestination(icon: Icon(Icons.map_rounded), label: "GRID MAP"),
              NavigationDestination(icon: Icon(Icons.leaderboard_rounded), label: "RANKS"),
              NavigationDestination(icon: Icon(Icons.groups_rounded), label: "TEAMS"),
              NavigationDestination(icon: Icon(Icons.person_rounded), label: "PROFILE"),
            ],
          ),
        ),
      ),
    );
  }
}
