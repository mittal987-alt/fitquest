import 'package:intl/intl.dart';
import '../models/player_model.dart';

class HealthReportService {
  Map<String, dynamic> generateWeeklySummary(PlayerModel player) {
    int totalSteps = 0;
    int daysActive = 0;
    Map<String, int> dailyBreakdown = {};

    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      
      if (player.dailyHistory.containsKey(dateString)) {
        final dayData = player.dailyHistory[dateString];
        int steps = dayData['steps'] ?? 0;
        totalSteps += steps;
        daysActive++;
        dailyBreakdown[dateString] = steps;
      }
    }

    return {
      "totalSteps": totalSteps,
      "averageSteps": daysActive > 0 ? totalSteps ~/ daysActive : 0,
      "daysActive": daysActive,
      "dailyBreakdown": dailyBreakdown,
    };
  }
}
