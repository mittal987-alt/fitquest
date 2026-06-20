import 'dart:math';

import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class TerritoryService {

  // =========================
  // HEX SIZE
  // =========================

  static const double hexSize = 0.0005;

  // =========================
  // GET HEX ID
  // =========================

  String getHexId(
      double lat,
      double lng, {
        double? customHexSize,
      }) {
    final size = customHexSize ?? hexSize;

    int q =
    (lng / (size * 1.5))
        .round();

    int r =
    (lat / (size * 1.732))
        .round();

    return "${q}_$r";
  }
  // =========================
  // GET HEX CENTER
  // =========================

  LatLng getHexCenter(
      String tileId, {
        double? customHexSize,
      }) {
    final size = customHexSize ?? hexSize;

    final parts = tileId.split("_");

    int q = int.parse(parts[0]);
    int r = int.parse(parts[1]);

    double x = q * size * 1.5;

    double y = r * size * 1.732;

    return LatLng(
      y,
      x,
    );
  }

  // =========================
  // CREATE HEXAGON
  // =========================

  List<LatLng> createHexagon(
      LatLng center,
      double radius,
      ) {
    List<LatLng> points = [];

    for (int i = 0; i < 6; i++) {
      double angle =
          pi / 180 * (60 * i);

      double lat =
          center.latitude +
              radius * sin(angle);

      double lng =
          center.longitude +
              radius * cos(angle);

      points.add(
        LatLng(lat, lng),
      );
    }

    return points;
  }

  // =========================
  // TEAM COLOR
  // =========================

  Color getTeamColor(
      String team) {

    switch (team) {

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

  // =========================
  // GENERATE WORLD GRID
  // =========================

  Set<Polygon> generateWorldGrid({
    required LatLng currentPosition,
    required Set<String> capturedTiles,
    required Map<String, String> tileOwners,
  }) {
    final Set<Polygon> hexagons = {};
    int id = 0;

    int playerQ = (currentPosition.longitude / (hexSize * 1.3)).floor();
    int playerR = (currentPosition.latitude / (hexSize * 1.5)).floor();

    for (int q = playerQ - 8; q <= playerQ + 8; q++) {
      for (int r = playerR - 8; r <= playerR + 8; r++) {
        double centerLng = q * (hexSize * 1.3);
        double centerLat = r * (hexSize * 1.5);

        if (r.isOdd) {
          centerLng += hexSize * 0.75;
        }

        String tileId = "${q}_$r";
        List<LatLng> points = createHexagon(
          LatLng(centerLat, centerLng),
          hexSize,
        );

        Color tileColor =
        Colors.grey
            .withValues(alpha: 0.08);

        // CAPTURED TILE
        if (capturedTiles
            .contains(tileId)) {

          String? team =
          tileOwners[tileId];

          if (team != null) {

            tileColor =
                getTeamColor(team)
                    .withValues(
                    alpha: 0.5);
          }
        }

        hexagons.add(

          Polygon(

            polygonId:
            PolygonId(
              "hex_$id",
            ),

            points: points,

            fillColor:
            tileColor,

            strokeColor:
            Colors.white24,

            strokeWidth: 1,
          ),
        );

        id++;
      }
    }

    return hexagons;
  }


  // =========================
  // ATTACK CHECK
  // =========================

  bool isEnemyTile({

    required String? ownerTeam,

    required String myTeam,
  }) {

    return ownerTeam != null &&
        ownerTeam != myTeam;
  }

  // =========================
  // EMPTY TILE CHECK
  // =========================

  bool isEmptyTile({

    required bool alreadyCaptured,
  }) {

    return !alreadyCaptured;
  }
}