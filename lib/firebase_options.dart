import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;

      default:
        throw UnsupportedError(
          'FirebaseOptions not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBueMcRT8oZp-725XbpVNdaDVfWnj6PraU',
    // Fixed: Updated to match your actual com.fitquest.game App ID profile
    appId: '1:78178298285:android:7d21cefb60dd5f60d19924',
    messagingSenderId: '78178298285',
    projectId: 'territory-game-462f9',
    storageBucket: 'territory-game-462f9.firebasestorage.app',
  );
}