import 'package:flutter/material.dart';

class TeamModel {

  final String id;

  final String name;

  final String color;

  final int members;

  final int maxMembers;

  final int totalLand;

  final int totalSteps;

  final String leaderId;

  final String logo;

  TeamModel({

    required this.id,

    required this.name,

    required this.color,

    required this.members,

    required this.maxMembers,

    required this.totalLand,

    required this.totalSteps,

    required this.leaderId,

    required this.logo,
  });

  // =========================
  // FROM FIREBASE
  // =========================

  factory TeamModel.fromMap(
      Map<String, dynamic> map) {

    return TeamModel(

      id: map["id"] ?? "",

      name: map["name"] ?? "",

      color: map["color"] ?? "blue",

      members: map["members"] ?? 0,

      maxMembers:
      map["maxMembers"] ?? 50,

      totalLand:
      map["totalLand"] ?? 0,

      totalSteps:
      map["totalSteps"] ?? 0,

      leaderId:
      map["leaderId"] ?? "",

      logo: map["logo"] ?? "",
    );
  }

  // =========================
  // TO FIREBASE
  // =========================

  Map<String, dynamic> toMap() {

    return {

      "id": id,

      "name": name,

      "color": color,

      "members": members,

      "maxMembers":
      maxMembers,

      "totalLand":
      totalLand,

      "totalSteps":
      totalSteps,

      "leaderId":
      leaderId,

      "logo": logo,
    };
  }

  // =========================
  // TEAM COLOR
  // =========================

  Color getTeamColor() {

    switch (color) {

      case "red":
        return Colors.red;

      case "green":
        return Colors.green;

      case "yellow":
        return Colors.orange;

      case "purple":
        return Colors.purple;

      default:
        return Colors.blue;
    }
  }
}