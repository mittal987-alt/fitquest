import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'controller/raid_controller.dart';
import 'controller/relay_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final notificationService = NotificationService();
  await notificationService.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<FirebaseService>(create: (_) => FirebaseService()),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<NotificationService>.value(value: notificationService),
        Provider<RelayController>(create: (_) => RelayController()),
        ChangeNotifierProvider<RaidController>(create: (_) => RaidController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "FitQuest",
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          primary: Colors.blueAccent,
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
          ),
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const MainNavigation();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
