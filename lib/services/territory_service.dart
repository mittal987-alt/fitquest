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
    // Standard Hex Offset Grid (Odd-R) calculation
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
      // Pointy-top hex orientation (30 deg start)
      double angleDeg = 60 * i - 30;
      double angleRad = pi / 180 * angleDeg;

      points.add(LatLng(
        center.latitude + radius * sin(angleRad),
        center.longitude + (radius * cos(angleRad)) / cos(center.latitude * pi / 180),
      ));
    }
    return points;
  }

  // =========================
  // TEAM COLOR
  // =========================
  Color getTeamColor(String team) {
    switch (team) {
      case "red": return Colors.red;
      case "green": return Colors.green;
      case "yellow": return Colors.orange;
      case "purple": return Colors.purple;
      case "blue": return Colors.blue;
      default: return Colors.orange; // Default solo
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

    // 1. DYNAMIC BOUNDING BOX CREATION
    // We parse all current tiles to find the spatial boundaries (min/max coordinates)
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

    // Pad the bounding box by 2 extra layers of hexes to ensure the flood fill
    // can completely loop *around* the outside of the player's trail.
    minQ -= 2; maxQ += 2;
    minR -= 2; maxR += 2;

    // Build the finalized evaluation pool space
    Set<String> boundedMapSpace = {};
    for (int q = minQ; q <= maxQ; q++) {
      for (int r = minR; r <= maxR; r++) {
        boundedMapSpace.add("${q}_$r");
      }
    }

    Set<String> outsideTiles = {};
    List<String> queue = [];

    // 2. Identify outer edge tiles of our newly padded bounding rectangle
    for (String tileId in boundedMapSpace) {
      final parts = tileId.split("_");
      int q = int.parse(parts[0]);
      int r = int.parse(parts[1]);

      // If it is on the literal boundary layer of the matrix box, it is safely "Outside"
      if (q == minQ || q == maxQ || r == minR || r == maxR) {
        if (!currentTrail.contains(tileId) && !ownedTerritory.contains(tileId)) {
          queue.add(tileId);
          outsideTiles.add(tileId);
        }
      }
    }

    // 3. BFS Flood Fill
    while (queue.isNotEmpty) {
      String current = queue.removeAt(0);

      for (String neighbor in getNeighbors(current)) {
        // Must stay inside our generated virtual box limits
        if (boundedMapSpace.contains(neighbor) &&
            !outsideTiles.contains(neighbor) &&
            !currentTrail.contains(neighbor) &&
            !ownedTerritory.contains(neighbor)) {

          outsideTiles.add(neighbor);
          queue.add(neighbor);
        }
      }
    }

    // 4. Inversion Step
    Set<String> freshlyCaptured = {};
    for (String tileId in boundedMapSpace) {
      if (!outsideTiles.contains(tileId) && !ownedTerritory.contains(tileId)) {
        freshlyCaptured.add(tileId);
      }
    }

    freshlyCaptured.addAll(currentTrail);
    return freshlyCaptured;
  }

// Simple boundary helper
  bool isMapEdgeTile(String tileId, List<String> totalPool) {
    // If any neighbor of this tile doesn't even exist in your active pool,
    // it means it sits right on the outer perimeter of your gameplay zone.
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
      // Odd row offsets
      offsets = [
        [1, 0],   // Right
        [-1, 0],  // Left
        [0, -1],  // Top-Right
        [-1, -1], // Top-Left
        [0, 1],   // Bottom-Right
        [-1, 1],  // Bottom-Left
      ];
    } else {
      // Even row offsets
      offsets = [
        [1, 0],   // Right
        [-1, 0],  // Left
        [1, -1],  // Top-Right
        [0, -1],  // Top-Left
        [1, 1],   // Bottom-Right
        [0, 1],   // Bottom-Left
      ];
    }

    return offsets.map((offset) {
      int neighborQ = q + offset[0];
      int neighborR = r + offset[1];
      return "${neighborQ}_$neighborR";
    }).toList();
  }

  // =========================
  // LOGIC CHECKS
  // =========================
  bool isEnemyTile({required String? ownerTeam, required String myTeam}) {
    return ownerTeam != null && ownerTeam != myTeam;
  }

  bool isEmptyTile({required bool alreadyCaptured}) {
    return !alreadyCaptured;
  }
}
