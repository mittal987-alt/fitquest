import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TerritoryService {
  // =========================
  // HEX SIZE
  // =========================
  static const double hexSize = 0.0001; // Approx 11 meters
  static const double sqrt3 = 1.7320508;

  // =========================
  // GET HEX ID (Odd-R Offset)
  // =========================
  String getHexId(double lat, double lng) {
    int r = (lat / (hexSize * 1.5)).round();
    double offset = (r % 2 != 0) ? (hexSize * sqrt3 / 2) : 0;
    int q = ((lng - offset) / (hexSize * sqrt3)).round();

    return "${q}_$r";
  }

  // =========================
  // GET HEX CENTER
  // =========================
  LatLng getHexCenter(String tileId) {
    final parts = tileId.split("_");
    int q = int.parse(parts[0]);
    int r = int.parse(parts[1]);

    double lat = r * (hexSize * 1.5);
    double offset = (r % 2 != 0) ? (hexSize * sqrt3 / 2) : 0;
    double lng = q * (hexSize * sqrt3) + offset;

    return LatLng(lat, lng);
  }

  // =========================
  // CREATE HEXAGON
  // =========================
  List<LatLng> createHexagon(LatLng center, double radius) {
    List<LatLng> points = [];
    for (int i = 0; i < 6; i++) {
      double angleDeg = 60 * i - 30;
      double angleRad = pi / 180 * angleDeg;

      points.add(LatLng(
        center.latitude + radius * sin(angleRad),
        center.longitude + (radius * cos(angleRad)) / cos(center.latitude * pi / 180),
      ));
    }
    return points;
  }

  // ==========================================================
  // NATIVE TERRITORY FUSION (Removes internal grid lines)
  // ==========================================================
  List<Polygon> buildUnifiedTerritory({
    required String groupKey,
    required List<String> tileIds,
    required Color color,
    required Function(String) onTap,
    Set<String>? strongholdTileIds,
  }) {
    List<Polygon> finalPolygons = [];

    // Convert to Set for O(1) instantaneous lookups
    final Set<String> groupSet = tileIds.toSet();

    for (int i = 0; i < tileIds.length; i++) {
      String tileId = tileIds[i];
      LatLng center = getHexCenter(tileId);
      List<LatLng> points = createHexagon(center, hexSize);

      bool isStronghold = strongholdTileIds?.contains(tileId) ?? false;

      // CRITICAL FIX: Check if this tile touches a space NOT owned by this specific group
      bool isActualEdge = false;
      for (String neighbor in getNeighbors(tileId)) {
        if (!groupSet.contains(neighbor)) {
          isActualEdge = true;
          break;
        }
      }

      finalPolygons.add(
        Polygon(
          polygonId: PolygonId("${groupKey}_cell_$tileId"),
          points: points,
          consumeTapEvents: true,
          onTap: () => onTap(tileId),
          // Strongholds have deeper, more saturated colors
          fillColor: isStronghold
              ? color.withValues(alpha: 0.6)
              : color.withValues(alpha: 0.35),
          strokeColor: isStronghold
              ? Colors.white.withValues(alpha: 0.8)
              : (isActualEdge ? color.withValues(alpha: 0.9) : Colors.transparent),
          strokeWidth: isStronghold ? 4 : (isActualEdge ? 3 : 0),
          zIndex: isStronghold ? 2 : 1,
        ),
      );
    }

    return finalPolygons;
  }

  // =========================
  // TEAM COLOR
  // =========================
  Color getTeamColor(String color, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (color) {
      case "red": return colorScheme.error;
      case "green": return Colors.green;
      case "yellow": return colorScheme.tertiary;
      case "purple": return Colors.purple;
      case "blue": return colorScheme.primary;
      case "orange": return colorScheme.secondary;
      default: return colorScheme.outline;
    }
  }

  // ==========================================
  // CALCULATE CAPTURED TILES (Fixed Bound Box)
  // ==========================================
  Set<String> calculateCapturedTiles({
    required Set<String> currentTrail,
    required Set<String> ownedTerritory,
    required List<String> allActiveGameTiles,
  }) {
    if (currentTrail.isEmpty) return {};

    Set<String> localProcessingPool = Set.from(allActiveGameTiles);
    localProcessingPool.addAll(currentTrail);
    localProcessingPool.addAll(ownedTerritory);

    int minQ = 9999999, maxQ = -9999999;
    int minR = 9999999, maxR = -9999999;

    for (String tileId in localProcessingPool) {
      final parts = tileId.split("_");
      int q = int.parse(parts[0]);
      int r = int.parse(parts[1]);
      if (q < minQ) minQ = q;
      if (q > maxQ) maxQ = q;
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
    }

    minQ -= 2; maxQ += 2;
    minR -= 2; maxR += 2;

    Set<String> boundedMapSpace = {};
    for (int q = minQ; q <= maxQ; q++) {
      for (int r = minR; r <= maxR; r++) {
        boundedMapSpace.add("${q}_$r");
      }
    }

    Set<String> outsideTiles = {};
    List<String> queue = [];

    for (String tileId in boundedMapSpace) {
      final parts = tileId.split("_");
      int q = int.parse(parts[0]);
      int r = int.parse(parts[1]);

      if (q == minQ || q == maxQ || r == minR || r == maxR) {
        if (!currentTrail.contains(tileId) && !ownedTerritory.contains(tileId)) {
          queue.add(tileId);
          outsideTiles.add(tileId);
        }
      }
    }

    while (queue.isNotEmpty) {
      String current = queue.removeAt(0);

      for (String neighbor in getNeighbors(current)) {
        if (boundedMapSpace.contains(neighbor) &&
            !outsideTiles.contains(neighbor) &&
            !currentTrail.contains(neighbor) &&
            !ownedTerritory.contains(neighbor)) {

          outsideTiles.add(neighbor);
          queue.add(neighbor);
        }
      }
    }

    Set<String> freshlyCaptured = {};
    for (String tileId in boundedMapSpace) {
      if (!outsideTiles.contains(tileId) && !ownedTerritory.contains(tileId)) {
        freshlyCaptured.add(tileId);
      }
    }

    freshlyCaptured.addAll(currentTrail);
    return freshlyCaptured;
  }

  bool isMapEdgeTile(String tileId, List<String> totalPool) {
    for (String neighbor in getNeighbors(tileId)) {
      if (!totalPool.contains(neighbor)) return true;
    }
    return false;
  }

  // =========================
  // GET NEIGHBOR TILE IDS
  // =========================
  List<String> getNeighbors(String tileId) {
    final parts = tileId.split("_");
    int q = int.parse(parts[0]);
    int r = int.parse(parts[1]);

    List<List<int>> offsets;

    if (r % 2 != 0) {
      offsets = [
        [1, 0], [-1, 0], [0, -1], [-1, -1], [0, 1], [-1, 1],
      ];
    } else {
      offsets = [
        [1, 0], [-1, 0], [1, -1], [0, -1], [1, 1], [0, 1],
      ];
    }

    return offsets.map((offset) {
      int neighborQ = q + offset[0];
      int neighborR = r + offset[1];
      return "${neighborQ}_$neighborR";
    }).toList();
  }

  bool isEnemyTile({required String? ownerTeam, required String myTeam}) {
    return ownerTeam != null && ownerTeam != myTeam;
  }

  bool isEmptyTile({required bool alreadyCaptured}) {
    return !alreadyCaptured;
  }
}