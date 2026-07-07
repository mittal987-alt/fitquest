import 'package:flutter/material.dart';

class PowerUp {
  final String id;
  final String name;
  final String description;
  final int cost;
  final IconData icon;
  final Color color;
  final Duration duration;

  PowerUp({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.icon,
    required this.color,
    required this.duration,
  });
}

final List<PowerUp> shopItems = [
  PowerUp(
    id: "shield",
    name: "Territory Shield",
    description: "Protect your territories from attacks for 2 hours.",
    cost: 500,
    icon: Icons.shield,
    color: Colors.blue,
    duration: const Duration(hours: 2),
  ),
  PowerUp(
    id: "boost",
    name: "XP Booster",
    description: "Earn 2x XP from walking for the next 30 minutes.",
    cost: 300,
    icon: Icons.bolt,
    color: Colors.amber,
    duration: const Duration(minutes: 30),
  ),
  PowerUp(
    id: "radar",
    name: "Mega Radar",
    description: "Capture territories from twice the distance for 1 hour.",
    cost: 800,
    icon: Icons.radar,
    color: Colors.purple,
    duration: const Duration(hours: 1),
  ),
  PowerUp(
    id: "energy_boost",
    name: "Energy Boost",
    description: "1.5x XP and Raid Damage after a fitness session.",
    cost: 0,
    icon: Icons.offline_bolt,
    color: Colors.orange,
    duration: const Duration(minutes: 60),
  ),
];
