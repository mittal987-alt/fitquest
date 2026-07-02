import 'dart:async';
import 'dart:ui';
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
  String? _mapStyleJson;

  Set<String> myOwnedTileIds = {};

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    initializeLocation();
    listenToHexTiles();
    startRegenLoop();
  }

  void _loadMapStyle() async {
    try {
      String style = await DefaultAssetBundle.of(context)
          .loadString('assets/map_style_light.json');
      setState(() {
        _mapStyleJson = style;
      });
    } catch (e) {
      debugPrint("Error loading map style configuration: $e");
    }
  }

  void listenToHexTiles() {
    hexTilesStream?.cancel();

    hexTilesStream = firebaseService.getHexTiles().listen((tiles) {
      allTiles = tiles;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String myUid = user.isAnonymous ? "anon" : user.uid;
        myOwnedTileIds = tiles
            .where((t) => t.ownerId == myUid)
            .map((t) => t.tileId)
            .toSet();
      }

      generateGrid();
      if (mounted) setState(() {});
    });
  }

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

  Position? lastPosition;
  DateTime? lastTimestamp;

  void startTracking() {
    positionStream?.cancel();
    positionStream = locationService.getLocationStream().listen(
          (position) async {
        // High-accuracy GPS tracking strictly in the foreground
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
                  backgroundColor: Colors.redAccent,
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
    bool captureBlocked = antiCheatService.captureBlocked;

    double distToCenter = locationService.calculateDistance(
      startLat: currentPosition.latitude,
      startLng: currentPosition.longitude,
      endLat: tileCenter.latitude,
      endLng: tileCenter.longitude,
    );

    if (!antiCheatService.canCapture(
      userIsWalking: isWalking,
      captureBlocked: captureBlocked,
      distanceToTileMeters: distToCenter,
    )) {
      return;
    }

    String ownerId = player.isInTeam ? (player.teamId ?? player.uid) : player.uid;
    String ownerType = player.isInTeam ? "team" : "solo";
    String ownerName = player.isInTeam ? player.team : player.name;
    String tileColor = player.isInTeam ? "blue" : "orange";

    myOwnedTileIds = allTiles.where((t) => t.ownerId == ownerId).map((t) => t.tileId).toSet();
    if (myOwnedTileIds.contains(tileId)) {
      lastCapturedTile = tileId;
      return;
    }

    HexTileModel newTile = HexTileModel(
      tileId: tileId,
      latitude: tileCenter.latitude,
      longitude: tileCenter.longitude,
      ownerType: ownerType,
      ownerId: ownerId,
      ownerName: ownerName,
      color: tileColor,
      power: 100,
      capturedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await firebaseService.saveHexTile(newTile);

    allTiles.removeWhere((t) => t.tileId == tileId);
    allTiles.add(newTile);
    lastCapturedTile = tileId;

    await firebaseService.incrementXP(uid: player.uid, xpToAdd: 15);

    final myTilesCount = allTiles.where((t) => t.ownerId == ownerId).length;
    if (player.isInTeam && player.teamId != null) {
      await firebaseService.updateTeamLand(teamId: player.teamId!, totalLand: myTilesCount);
    } else {
      await firebaseService.updateLand(uid: player.uid, totalLand: myTilesCount);
    }

    generateGrid();
    if (mounted) setState(() {});
  }

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
          const SnackBar(backgroundColor: Colors.redAccent, content: Text("You can only defend your own territory")),
        );
      }
      return;
    }

    if (tile.power >= 100) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.blueAccent, content: Text("Territory already at max power")),
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

  void showTileDetails(HexTileModel tile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      tile.ownerName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tile.ownerType == "solo" ? "⚔️ Solo Domain" : "🛡️ Squad Domain",
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black54, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Fortification HP", style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.bold)),
                  Text("${tile.power}/100", style: const TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LinearProgressIndicator(
                  value: tile.power / 100,
                  minHeight: 12,
                  backgroundColor: Colors.black.withValues(alpha: 0.05),
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
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await attackTile(tile);
                      },
                      icon: const Icon(Icons.flash_on_rounded),
                      label: const Text("ATTACK", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                        foregroundColor: Colors.blueAccent,
                        elevation: 0,
                        side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.2), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await defendTile(tile);
                      },
                      icon: const Icon(Icons.shield_rounded),
                      label: const Text("FORTIFY", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

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

  void generateGrid() {
    hexagons.clear();

    Map<String, List<HexTileModel>> groupedTiles = {};
    for (var tile in allTiles) {
      String key = "${tile.ownerId}_${tile.color}";
      groupedTiles.putIfAbsent(key, () => []).add(tile);
    }

    groupedTiles.forEach((key, tiles) {
      if (tiles.isEmpty) return;

      var sampleTile = tiles.first;
      Color territoryColor = Colors.blueGrey;
      if (sampleTile.ownerType == "solo") {
        territoryColor = Colors.orange;
      } else {
        switch (sampleTile.color) {
          case "blue": territoryColor = Colors.blue; break;
          case "red": territoryColor = Colors.red; break;
          case "green": territoryColor = Colors.green; break;
          case "yellow": territoryColor = Colors.orange; break;
          case "purple": territoryColor = Colors.purple; break;
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
            style: _mapStyleJson,
            polygons: hexagons,
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            onMapCreated: (controller) {
              mapController = controller;
            },
          ),

          if (antiCheatService.isCaptureBlocked)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.speed_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        "EXCESSIVE VELOCITY! Capture array disabled.",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      speedKmh > 1.0 ? Icons.directions_run_rounded : Icons.accessibility_new_rounded,
                      color: Colors.blueAccent,
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
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "${speedKmh.toStringAsFixed(1)} KM/H",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
