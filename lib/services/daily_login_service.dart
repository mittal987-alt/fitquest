import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_service.dart';

class DailyLoginService {
  static Future<void> checkLogin(BuildContext context) async {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final user = firebaseService.currentUser;
    if (user != null) {
      await firebaseService.checkAndResetDailyStats(user.uid);
    }
  }
}
