import 'package:flutter/material.dart';

extension GameTheme on ColorScheme {
  /// XP Orange - used for experience, levels, and progress.
  Color get xp => const Color(0xFFFF9800);

  /// Health Red - used for HP, health bars, and damage.
  Color get health => const Color(0xFFF44336);

  /// Energy Blue - used for stamina, power, and MP.
  Color get energy => const Color(0xFF2196F3);

  /// Level Gold - used for high-tier rewards and level indicators.
  Color get gold => const Color(0xFFFFD700);

  /// Success Green - used for completed goals and positive outcomes.
  Color get success => const Color(0xFF4CAF50);
}
