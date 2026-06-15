import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    // Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM Token
    String? token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }

    // Refresh token listener
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Background/Terminated click listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification clicked: ${message.data}");
      // Can add navigation logic here if needed
    });
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('players').doc(user.uid).update({
        'fcmToken': token,
      });
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'game_alerts',
      'Game Alerts',
      channelDescription: 'Notifications for game events like capturing tiles',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      id ?? DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
    );
  }

  void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'territory_alerts',
            'Territory Alerts',
            channelDescription: 'Notifications for territory attacks and captures',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }

  // Helper for topic subscription (e.g. team notifications)
  Future<void> subscribeToTeam(String teamId) async {
    await _fcm.subscribeToTopic('team_$teamId');
  }

  Future<void> unsubscribeFromTeam(String teamId) async {
    await _fcm.unsubscribeFromTopic('team_$teamId');
  }
}
