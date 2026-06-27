import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Define a high-importance channel configuration block for Android layout routing
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'squad_notification_channel', // Match this with your payload/manifest channel ID
    'Tactical Squad Notifications', // User-visible title inside app settings
    description: 'Real-time telemetry and squad updates.',
    importance: Importance.max,
    playSound: true,
  );

  Future<void> initialize() async {
    // 1. Request remote alert credentials and check platform payload clearance
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Update iOS foreground presentation specs to flash alerts while running active app states
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Instantiate and wire up native background message processing vectors
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Initialize local notification engine bindings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(initSettings);

    // Create the mandatory high-importance channel on the Android native system layout layer
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Bind incoming foreground streaming events directly into our local display renderer
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showLocalNotification(
          title: message.notification!.title ?? "TACTICAL INBOUND",
          body: message.notification!.body ?? "",
        );
      }
    });
  }

  Future<void> showLocalNotification({required String title, required String body}) async {
    // Reference the exact channel assigned during initialization to bypass Android suppression rules
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();
    final platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000, // Generate distinct integer tags to avoid overwrite overrides
      title,
      body,
      platformDetails,
    );
  }

  // ==========================================
  // TOPIC CHANNEL CONNECTIONS
  // ==========================================

  Future<void> subscribeToTeam(String teamId) async {
    try {
      await _fcm.subscribeToTopic('team_$teamId');
      debugPrint("📡 NETWORK: Registered on topic broadcast vector -> team_$teamId");
    } catch (e) {
      debugPrint("❌ NETWORK FAULT: Topic registration dropped -> $e");
    }
  }

  Future<void> unsubscribeFromTeam(String teamId) async {
    try {
      await _fcm.unsubscribeFromTopic('team_$teamId');
      debugPrint("📡 NETWORK: Severed topic broadcast connection -> team_$teamId");
    } catch (e) {
      debugPrint("❌ NETWORK FAULT: Topic severance dropped -> $e");
    }
  }
}

// Global background worker node processing thread allocation mapping
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("📡 BACKGROUND TELEMETRY RECEIVED: ID reference context -> ${message.messageId}");
}