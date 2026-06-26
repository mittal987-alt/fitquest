

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_model.dart';
import '../services/location_service.dart';
import '../services/pedometer_service.dart';
import '../services/territory_service.dart';
import '../services/anti_cheat_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import 'package:provider/provider.dart';
import '../models/hex_tile_model.dart';
import '../models/player_model.dart';
import '../widgets/movement_status_card.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  final LocationService locationService = LocationService();
  final PedometerService pedometerService = PedometerService();
  final TerritoryService territoryService = TerritoryService();
  final AntiCheatService antiCheatService = AntiCheatService();
  final FirebaseService firebaseService = FirebaseService();

  StreamSubscription<Position>? positionStream;
  StreamSubscription<List<HexTileModel>>? hexTilesStream;
  LatLng currentPosition = const LatLng(28.6139, 77.2090);
  final Set<Polygon> hexagons = {};
  final Set<Marker> markers = {};
  List<HexTileModel> allTiles = [];
  double speedKmh = 0;
  String? lastCapturedTile;

  // ==========================================
  // TERRITORY CAPTURE TRACKING STATES
  // ==========================================
  final Set<String> playerTrail = {}; // Temporary hex trail drawn outside
  Set<String> myOwnedTileIds = {};   // Cached set of current owned hex IDs

  @override
  void initState() {
    super.initState();
    initializeLocation();
    listenToHexTiles();
    startRegenLoop();
  }

  // =========================
  // FIREBASE TILES STREAM
  // =========================
  void listenToHexTiles() {
    hexTilesStream?.cancel();

    hexTilesStream = firebaseService.getHexTiles().listen((tiles) {
      debugPrint("TOTAL TILES FROM FIRESTORE = ${tiles.length}");
      allTiles = tiles;

      // ----------------------------------------------------
      // ENEMY INTERSECTION CHECK (Paper.io Trail Splitting)
      // ----------------------------------------------------
      if (playerTrail.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          String myUid = user.isAnonymous? "anon" : user.uid;
          for (var tile in tiles) {
            // If the tile was claimed by an enemy but sits in your current local active trail...
            if (tile.ownerId != myUid && playerTrail.contains(tile.tileId)) {
              debugPrint("TRAIL SNAPPED! Enemy ${tile.ownerName} crossed your trail at ${tile.tileId}");
              handleTrailSnapped();
              break;
            }
          }
        }
      }

      generateGrid();
      if (mounted) setState(() {});
    });
  }

  void handleTrailSnapped() {
    playerTrail.clear();
    lastCapturedTile = null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.gavel, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Your trail was cut by an enemy! Expansion reset.",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ),
      );
    }
    generateGrid();
    if (mounted) setState(() {});
  }

  // =========================
  // INITIALIZE LOCATION
  // =========================
  Future<void> initializeLocation() async {
    bool granted = await locationService.checkPermission();
    if (!granted) return;

    Position position = await locationService.getCurrentLocation();
    currentPosition = LatLng(position.latitude, position.longitude);

    updatePlayerMarker();
    generateGrid();
    startTracking();
    if (mounted) setState(() {});
  }

  // =========================
  // START TRACKING
  // =========================
  Position? lastPosition;
  DateTime? lastTimestamp;

  void startTracking() {
    positionStream?.cancel();
    positionStream = locationService.getLocationStream().listen(
          (position) async {
        final now = DateTime.now();
        double calculatedSpeed = position.speed * 3.6;

        final lPos = lastPosition;
        final lTime = lastTimestamp;
        if (lPos != null && lTime != null) {
          double distance = locationService.calculateDistance(
            startLat: lPos.latitude,
            startLng: lPos.longitude,
            endLat: position.latitude,
            endLng: position.longitude,
          );
          double timeDiff = now.difference(lTime).inMilliseconds / 1000.0;

          if (timeDiff > 0) {
            double manualSpeed = (distance / timeDiff) * 3.6;
            if (calculatedSpeed < 0.3 && manualSpeed > 0.3) {
              calculatedSpeed = manualSpeed;
            }
          }

          if (antiCheatService.isTeleportJump(distance, timeDiff)) {
            antiCheatService.applyTeleportPenalty();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Suspicious movement detected! Capture blocked."),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }

        speedKmh = calculatedSpeed;
        lastPosition = position;
        lastTimestamp = now;
        currentPosition = LatLng(position.latitude, position.longitude);

        if (!mounted) return;

        bool isWalking = antiCheatService.isWalking(speedKmh);

        if (antiCheatService.isVehicle(speedKmh)) {
          antiCheatService.applyVehicleWarning();
        }

        if (isWalking) {
          antiCheatService.resetCaptureBlock();
          await captureTile();
        }

        updatePlayerMarker();
        generateGrid();

        if (mounted && mapController != null) {
          try {
            await mapController!.animateCamera(
              CameraUpdate.newLatLng(currentPosition),
            );
          } catch (_) {}
        }
      },
    );
  }

  // =========================
  // REGEN LOOP
  // =========================
  void startRegenLoop() {
    Timer.periodic(
      const Duration(minutes: 2),
          (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        await regenerateTerritories();
      },
    );
  }

  // =========================
  // PLAYER MARKER
  // =========================
  void updatePlayerMarker() {
    markers.clear();
    markers.add(
      Marker(
        markerId: const MarkerId("player"),
        position: currentPosition,
        infoWindow: const InfoWindow(title: "You"),
      ),
    );
  }

  // ==========================================
  // CAPTURE TILE W/ ENCLOSURE SYSTEM
  // ==========================================
  Future<void> captureTile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    PlayerModel? player = await firebaseService.getPlayer(uid);
    if (player == null) return;

    String tileId = territoryService.getHexId(
      currentPosition.latitude,
      currentPosition.longitude,
    );

    if (lastCapturedTile == tileId) return;

    LatLng tileCenter = territoryService.getHexCenter(tileId);
    bool isWalking = antiCheatService.isWalking(speedKmh);
    bool realWalking = pedometerService.isRealWalking();
    bool captureBlocked = antiCheatService.captureBlocked;

    double distToCenter = locationService.calculateDistance(
      startLat: currentPosition.latitude,
      startLng: currentPosition.longitude,
      endLat: tileCenter.latitude,
      endLng: tileCenter.longitude,
    );

    if (!antiCheatService.canCapture(
      isWalking: isWalking,
      realWalking: realWalking,
      captureBlocked: captureBlocked,
      distanceToTile: distToCenter,
    )) {
      return;
    }

    String ownerId = player.isInTeam ? (player.teamId ?? player.uid) : player.uid;
    String ownerType = player.isInTeam ? "team" : "solo";
    String ownerName = player.isInTeam ? player.team : player.name;
    String tileColor = player.isInTeam ? "blue" : "orange";

    // Build immediate local lookup map for owned hexes
    myOwnedTileIds = allTiles.where((t) => t.ownerId == ownerId).map((t) => t.tileId).toSet();

    // CASE 1: Return to own ground -> Execute Area Enclosure Capture
    if (myOwnedTileIds.contains(tileId)) {
      if (playerTrail.isNotEmpty) {
        debugPrint("LOOP CLOSED! Calculating area polygon...");

        // Dynamically build a local grid context map bounding block
        List<String> activePool = allTiles.map((t) => t.tileId).toList();
        for (var trailId in playerTrail) {
          if (!activePool.contains(trailId)) activePool.add(trailId);
          for (var neighbor in territoryService.getNeighbors(trailId)) {
            if (!activePool.contains(neighbor)) activePool.add(neighbor);
          }
        }

        // Invoke the inversion flood-fill function
        Set<String> newlyWonTiles = territoryService.calculateCapturedTiles(
          currentTrail: playerTrail,
          ownedTerritory: myOwnedTileIds,
          allActiveGameTiles: activePool,
        );

        // Upload batch updates to Firestore database
        for (String wonId in newlyWonTiles) {
          LatLng wonCenter = territoryService.getHexCenter(wonId);
          HexTileModel newTile = HexTileModel(
            tileId: wonId,
            latitude: wonCenter.latitude,
            longitude: wonCenter.longitude,
            ownerType: ownerType,
            ownerId: ownerId,
            ownerName: ownerName,
            color: tileColor,
            power: 100,
            capturedAt: DateTime.now().millisecondsSinceEpoch,
          );

          await firebaseService.saveHexTile(newTile);
          allTiles.removeWhere((t) => t.tileId == wonId);
          allTiles.add(newTile);
        }

        playerTrail.clear();
        lastCapturedTile = tileId;

        await firebaseService.incrementXP(uid: player.uid, xpToAdd: 150);
        generateGrid();
        if (mounted) setState(() {});
      }
      return;
    }

    // CASE 2: Self-Intersection Protection
    if (playerTrail.contains(tileId)) {
      debugPrint("CRASHED INTO OWN PATH");
      playerTrail.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You crossed your own trail! Extension reset."),
            backgroundColor: Colors.red,
          ),
        );
      }
      generateGrid();
      if (mounted) setState(() {});
      return;
    }

    // CASE 3: Stepping on open grid field -> append trail path element
    playerTrail.add(tileId);
    lastCapturedTile = tileId;

    generateGrid();
    if (mounted) setState(() {});

    // Update individual XP/Land increments safely for active mapping tracking
    final myTilesCount = allTiles.where((t) => t.ownerId == ownerId).length;
    if (player.isInTeam && player.teamId != null) {
      await firebaseService.updateTeamLand(teamId: player.teamId!, totalLand: myTilesCount);
    } else {
      await firebaseService.updateLand(uid: player.uid, totalLand: myTilesCount);
    }
  }

  // =========================
  // ATTACK TILE
  // =========================
  Future<void> attackTile(HexTileModel tile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    PlayerModel? player = await firebaseService.getPlayer(uid);
    if (player == null) return;

    String? attackerId = player.isInTeam ? player.teamId : player.uid;
    if (attackerId == null) return;

    if (tile.ownerId == attackerId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You already own this territory")),
        );
      }
      return;
    }

    int newPower = tile.power - 20;

    if (newPower <= 0) {
      HexTileModel newTile = HexTileModel(
        tileId: tile.tileId,
        latitude: tile.latitude,
        longitude: tile.longitude,
        ownerType: player.isInTeam ? "team" : "solo",
        ownerId: attackerId,
        ownerName: player.isInTeam ? player.team : player.name,
        color: player.isInTeam ? "blue" : "orange",
        power: 100,
        capturedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await firebaseService.saveHexTile(newTile);

      int xpReward = 100;
      final boostExpiry = player.activePowerUps["boost"];
      if (boostExpiry != null && boostExpiry.isAfter(DateTime.now())) {
        xpReward *= 2;
      }
      await firebaseService.incrementXP(uid: player.uid, xpToAdd: xpReward);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text("Territory Captured!")),
        );
      }
    } else {
      HexTileModel damagedTile = HexTileModel(
        tileId: tile.tileId,
        latitude: tile.latitude,
        longitude: tile.longitude,
        ownerType: tile.ownerType,
        ownerId: tile.ownerId,
        ownerName: tile.ownerName,
        color: tile.color,
        power: newPower,
        capturedAt: tile.capturedAt,
      );

      await firebaseService.saveHexTile(damagedTile);
    }
  }

  // =========================
  // DEFEND TILE
  // =========================
  Future<void> defendTile(HexTileModel tile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    PlayerModel? player = await firebaseService.getPlayer(uid);
    if (player == null) return;

    String? attackerId = player.isInTeam ? player.teamId : player.uid;
    if (attackerId == null) return;

    if (tile.ownerId != attackerId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.red, content: Text("You can only defend your own territory")),
        );
      }
      return;
    }

    if (tile.power >= 100) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.blue, content: Text("Territory already at max power")),
        );
      }
      return;
    }

    int newPower = (tile.power + 10).clamp(0, 100);

    HexTileModel defendedTile = HexTileModel(
      tileId: tile.tileId,
      latitude: tile.latitude,
      longitude: tile.longitude,
      ownerType: tile.ownerType,
      ownerId: tile.ownerId,
      ownerName: tile.ownerName,
      color: tile.color,
      power: newPower,
      capturedAt: tile.capturedAt,
    );

    await firebaseService.saveHexTile(defendedTile);
    int xpReward = 20;
    final boostExpiry = player.activePowerUps["boost"];
    if (boostExpiry != null && boostExpiry.isAfter(DateTime.now())) {
      xpReward *= 2;
    }
    await firebaseService.incrementXP(uid: player.uid, xpToAdd: xpReward);
  }

  // =========================
  // TILE DETAILS SHEET
  // =========================
  void showTileDetails(HexTileModel tile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    tile.ownerType == "solo" ? Icons.person : Icons.groups,
                    size: 32,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tile.ownerName,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tile.ownerType == "solo" ? "Solo Territory" : "Team Territory",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Territory Power", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("${tile.power}/100", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LinearProgressIndicator(
                  value: tile.power / 100,
                  minHeight: 16,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(
                    tile.power > 70 ? Colors.green : tile.power > 40 ? Colors.orange : Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await attackTile(tile);
                      },
                      icon: const Icon(Icons.gps_fixed),
                      label: const Text("Attack"),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await defendTile(tile);
                      },
                      icon: const Icon(Icons.shield),
                      label: const Text("Defend"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // =========================
  // AUTO TERRITORY REGEN
  // =========================
  Future<void> regenerateTerritories() async {
    for (var tile in allTiles) {
      if (tile.power >= 100) continue;
      int newPower = (tile.power + 5).clamp(0, 100);

      HexTileModel regeneratedTile = HexTileModel(
        tileId: tile.tileId,
        latitude: tile.latitude,
        longitude: tile.longitude,
        ownerType: tile.ownerType,
        ownerId: tile.ownerId,
        ownerName: tile.ownerName,
        color: tile.color,
        power: newPower,
        capturedAt: tile.capturedAt,
      );

      await firebaseService.saveHexTile(regeneratedTile);
    }
  }

  // =========================
  // GENERATE MAP GRID
  // =========================
  void generateGrid() {
    hexagons.clear();

    // 1. Draw Captured Persistent Hexagons
    for (var tile in allTiles) {
      Color tileColor = Colors.grey;
      if (tile.ownerType == "solo") {
        tileColor = Colors.orange;
      } else {
        switch (tile.color) {
          case "blue": tileColor = Colors.blue; break;
          case "red": tileColor = Colors.red; break;
          case "green": tileColor = Colors.green; break;
          case "yellow": tileColor = Colors.yellow; break;
          case "purple": tileColor = Colors.purple; break;
        }
      }

      hexagons.add(
        Polygon(
          polygonId: PolygonId(tile.tileId),
          consumeTapEvents: true,
          onTap: () => showTileDetails(tile),
          points: territoryService.createHexagon(
            LatLng(tile.latitude, tile.longitude),
            TerritoryService.hexSize,
          ),
          fillColor: tileColor.withOpacity(0.45),
          strokeColor: tileColor,
          strokeWidth: 2,
        ),
      );
    }

    // 2. Overlay Live Temporary Trail Hexagons (Yellow Paper.io path feedback)
    for (var trailId in playerTrail) {
      LatLng trailCenter = territoryService.getHexCenter(trailId);
      hexagons.add(
        Polygon(
          polygonId: PolygonId("trail_$trailId"),
          points: territoryService.createHexagon(
            trailCenter,
            TerritoryService.hexSize,
          ),
          fillColor: Colors.yellow.withOpacity(0.55),
          strokeColor: Colors.yellowAccent,
          strokeWidth: 3,
        ),
      );
    }
  }

  @override
  void dispose() {
    positionStream?.cancel();
    hexTilesStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: currentPosition, zoom: 19),
            polygons: hexagons,
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            compassEnabled: true,
            onMapCreated: (controller) => mapController = controller,
          ),
          if (antiCheatService.isCaptureBlocked)
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Movement too fast! Capture disabled.",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: MovementStatusCard(
              status: antiCheatService.getMovementStatus(speedKmh),
              speed: speedKmh,
            ),
          ),
        ],
      ),
    );
  }
}

