import 'dart:async';
import 'dart:ui'; // Required for ImageFilter (Glassmorphism effect)
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/location_service.dart';
import '../services/pedometer_service.dart';
import '../services/territory_service.dart';
import '../services/anti_cheat_service.dart';
import '../services/firebase_service.dart';
import '../models/hex_tile_model.dart';
import '../models/player_model.dart';

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
  String? _mapStyleJson; // Store custom game theme json

  // ==========================================
  // TERRITORY CAPTURE TRACKING STATES
  // ==========================================
  final Set<String> playerTrail = {}; // Temporary hex trail drawn outside
  Set<String> myOwnedTileIds = {};   // Cached set of current owned hex IDs

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    initializeLocation();
    listenToHexTiles();
    startRegenLoop();
  }

  // =========================
  // LOAD MAP STYLE ASSET
  // =========================
  void _loadMapStyle() async {
    try {
      String style = await DefaultAssetBundle.of(context)
          .loadString('assets/map_style.json');
      setState(() {
        _mapStyleJson = style;
      });
      if (mapController != null && _mapStyleJson != null) {
        // The warning suggests using GoogleMap.style, but we'll stick to consistency for now 
        // if the controller is already initialized.
      }
    } catch (e) {
      debugPrint("Error loading map style configuration: $e");
    }
  }

  // =========================
  // FIREBASE TILES STREAM
  // =========================
  void listenToHexTiles() {
    hexTilesStream?.cancel();

    hexTilesStream = firebaseService.getHexTiles().listen((tiles) {
      debugPrint("TOTAL TILES FROM FIRESTORE = ${tiles.length}");
      allTiles = tiles;

      if (playerTrail.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          String myUid = user.isAnonymous ? "anon" : user.uid;
          for (var tile in tiles) {
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
        // Optional custom icon replacement goes here via BitmapDescriptor
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

    myOwnedTileIds = allTiles.where((t) => t.ownerId == ownerId).map((t) => t.tileId).toSet();

    if (myOwnedTileIds.contains(tileId)) {
      if (playerTrail.isNotEmpty) {
        debugPrint("LOOP CLOSED! Calculating area polygon...");

        List<String> activePool = allTiles.map((t) => t.tileId).toList();
        for (var trailId in playerTrail) {
          if (!activePool.contains(trailId)) activePool.add(trailId);
          for (var neighbor in territoryService.getNeighbors(trailId)) {
            if (!activePool.contains(neighbor)) activePool.add(neighbor);
          }
        }

        Set<String> newlyWonTiles = territoryService.calculateCapturedTiles(
          currentTrail: playerTrail,
          ownedTerritory: myOwnedTileIds,
          allActiveGameTiles: activePool,
        );

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

    playerTrail.add(tileId);
    lastCapturedTile = tileId;

    generateGrid();
    if (mounted) setState(() {});

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

  // ==========================================
  // TILE DETAILS BOTTOM SHEET (DARK GAMING UX)
  // ==========================================
  void showTileDetails(HexTileModel tile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Translucent framework
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        tile.ownerType == "solo" ? Icons.person_rounded : Icons.groups_rounded,
                        size: 36,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          tile.ownerName,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tile.ownerType == "solo" ? "⚔️ Solo Domain" : "🛡️ Squad Domain",
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Fortification HP", style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500)),
                      Text("${tile.power}/100", style: const TextStyle(fontSize: 16, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: LinearProgressIndicator(
                      value: tile.power / 100,
                      minHeight: 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(
                        tile.power > 70 ? Colors.greenAccent : tile.power > 40 ? Colors.orangeAccent : Colors.redAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent, width: 1),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await attackTile(tile);
                          },
                          icon: const Icon(Icons.flash_on_rounded),
                          label: const Text("ATTACK", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                            foregroundColor: Colors.greenAccent,
                            side: const BorderSide(color: Colors.greenAccent, width: 1),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await defendTile(tile);
                          },
                          icon: const Icon(Icons.shield_rounded),
                          label: const Text("FORTIFY", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

  // ==========================================
  // GENERATE GRID (CLEAN NEON STYLING)
  // ==========================================
  void generateGrid() {
    hexagons.clear();

    // Group tiles by owner/color to merge them into distinct custom kingdoms
    Map<String, List<HexTileModel>> groupedTiles = {};
    for (var tile in allTiles) {
      String key = "${tile.ownerId}_${tile.color}";
      groupedTiles.putIfAbsent(key, () => []).add(tile);
    }

    // 1. Draw Captured Persistent Merged Territories
    groupedTiles.forEach((key, tiles) {
      if (tiles.isEmpty) return;

      var sampleTile = tiles.first;
      Color territoryColor = Colors.blueGrey;
      if (sampleTile.ownerType == "solo") {
        territoryColor = Colors.orange;
      } else {
        switch (sampleTile.color) {
          case "blue": territoryColor = Colors.cyan; break;
          case "red": territoryColor = Colors.redAccent; break;
          case "green": territoryColor = Colors.greenAccent; break;
          case "yellow": territoryColor = Colors.amber; break;
          case "purple": territoryColor = Colors.purpleAccent; break;
        }
      }

      List<String> tileIds = tiles.map((t) => t.tileId).toList();
      hexagons.addAll(territoryService.buildUnifiedTerritory(
        groupKey: key,
        tileIds: tileIds,
        color: territoryColor,
        onTap: (tileId) {
          final tile = tiles.firstWhere((t) => t.tileId == tileId);
          showTileDetails(tile);
        },
      ));
    });

    // 2. Overlay Live Temporary Trail Hexagons (Keep distinct so path building stands out)
    for (var trailId in playerTrail) {
      LatLng trailCenter = territoryService.getHexCenter(trailId);
      hexagons.add(
        Polygon(
          polygonId: PolygonId("trail_$trailId"),
          points: territoryService.createHexagon(
            trailCenter,
            TerritoryService.hexSize,
          ),
          fillColor: Colors.yellowAccent.withValues(alpha: 0.35),
          strokeColor: Colors.yellow,
          strokeWidth: 2,
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

  // ==========================================
  // WIDGET SCREEN UI LAYER STACK
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. CORE MAP PANEL INTERFACE LAYER
          GoogleMap(
            initialCameraPosition: CameraPosition(target: currentPosition, zoom: 19),
            style: _mapStyleJson,
            polygons: hexagons,
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Turned off default button to save layout space
            zoomControlsEnabled: false,
            compassEnabled: false,
            onMapCreated: (controller) {
              mapController = controller;
            },
          ),

          // 2. ANTI-CHEAT WARNING LAYER ALERT BANNER
          if (antiCheatService.isCaptureBlocked)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.speed_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            "EXCESSIVE VELOCITY! Capture array disabled.",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 3. FLOATING GLASSMORPHISM INTERACTIVE TELEMETRY HUD
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          speedKmh > 1.0 ? Icons.directions_run_rounded : Icons.accessibility_new_rounded,
                          color: Colors.cyanAccent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              antiCheatService.getMovementStatus(speedKmh).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "${speedKmh.toStringAsFixed(1)} KM/H",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}