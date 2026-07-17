import 'package:flutter/material.dart';

class AchievementModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int xpReward;
  final int coinReward;
  final String category; // 'steps', 'distance', 'territory', 'team'

  AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.xpReward = 500,
    this.coinReward = 100,
    this.category = 'general',
  });
}

final List<AchievementModel> kGlobalAchievements = [
  AchievementModel(
    id: 'first_walk',
    title: 'FIRST CONTACT',
    description: 'Complete your first recorded walk.',
    icon: Icons.directions_walk,
    color: Colors.greenAccent,
    xpReward: 100,
    category: 'steps',
  ),
  AchievementModel(
    id: 'streak_7',
    title: 'UNSTOPPABLE',
    description: 'Maintain a 7-day login streak.',
    icon: Icons.whatshot,
    color: Colors.orangeAccent,
    xpReward: 500,
    category: 'general',
  ),
  AchievementModel(
    id: 'km_100',
    title: 'MARATHONER',
    description: 'Walk a total of 100km.',
    icon: Icons.speed,
    color: Colors.blueAccent,
    xpReward: 1000,
    category: 'distance',
  ),
  AchievementModel(
    id: 'territory_king',
    title: 'OVERLORD',
    description: 'Capture 50 or more unique sectors.',
    icon: Icons.map,
    color: Colors.purpleAccent,
    xpReward: 2000,
    category: 'territory',
  ),
  AchievementModel(
    id: 'team_player',
    title: 'OPERATIVE',
    description: 'Join a Tactical Unit (Team).',
    icon: Icons.group,
    color: Colors.cyanAccent,
    xpReward: 200,
    category: 'team',
  ),
];
