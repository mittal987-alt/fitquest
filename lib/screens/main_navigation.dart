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

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // 1. Request Permissions
    await [
      Permission.activityRecognition,
      Permission.locationWhenInUse,
    ].request();

    // 2. Setup Team Notifications
    _setupTeamNotifications();
    
    // 3. Start global tracking
    pedometerService.startListening();
    stepSyncService.startTracking();
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    stepSyncService.stopTracking();
    super.dispose();
  }

  void _setupTeamNotifications() {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final uid = firebaseService.auth.currentUser?.uid;
    
    if (uid != null) {
      _playerSubscription = firebaseService.getPlayerStream(uid).listen((player) {
        if (player != null && mounted) {
          final notificationService = Provider.of<NotificationService>(context, listen: false);
          
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
        }
      });
    }
  }

  final List<Widget> pages = [
    const HomeScreen(),
    const MapScreen(),
    const LeaderboardScreen(),
    const TeamScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        height: 75,
        backgroundColor: Colors.white,
        indicatorColor: Colors.blue.withValues(alpha: 0.15),
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.map),
            label: "Map",
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard),
            label: "Rank",
          ),
          NavigationDestination(
            icon: Icon(Icons.groups),
            label: "Teams",
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
