import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../services/location_service.dart';
import '../services/pedometer_service.dart';
import '../services/territory_service.dart';
import '../services/anti_cheat_service.dart';
import '../services/firebase_service.dart';
import '../models/hex_tile_model.dart';
import '../models/player_model.dart';
import '../models/bounty_model.dart';
import '../models/team_model.dart';
import '../models/gear_model.dart';

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
  StreamSubscription<List<BountyModel>>? bountiesStream;
  StreamSubscription<List<TeamModel>>? teamsStream;

  LatLng currentPosition = const LatLng(28.6139, 77.2090);
  final Set<Polygon> hexagons = {};
  final Set<Marker> markers = {};
  final Set<Circle> circles = {};
  final Set<Polyline> polylines = {};
  List<LatLng> breadcrumbs = [];
  String? trackedBountyId;
  List<HexTileModel> allTiles = [];
  List<BountyModel> allBounties = [];
  List<TeamModel> allTeams = [];
  List<GearModel> allGear = [];
  PlayerModel? currentPlayer;
  StreamSubscription<PlayerModel?>? playerStream;
  StreamSubscription<List<GearModel>>? gearStream;

  BitmapDescriptor? playerIcon;
  String? lastAvatarUrl;

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
    listenToBounties();
    listenToTeams();
    listenToPlayer();
    listenToGear();
    startRegenLoop();
  }

  void listenToGear() {
    gearStream?.cancel();
    gearStream = firebaseService.getGear().listen((gear) {
      if (mounted) {
        setState(() {
          allGear = gear;
        });
      }
    });
  }

  void listenToPlayer() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      playerStream?.cancel();
      playerStream = firebaseService.getPlayerStream(user.uid).listen((p) async {
        if (mounted && p != null) {
          if (p.avatar != lastAvatarUrl) {
            lastAvatarUrl = p.avatar;
            await _updatePlayerIcon(p.avatar);
          }
          setState(() {
            currentPlayer = p;
            updateMarkers();
          });
        }
      });
    }
  }

  void listenToBounties() {
    bountiesStream?.cancel();
    bountiesStream = firebaseService.getActiveBounties().listen((bounties) {
      allBounties = bounties;
      updateMarkers();
      if (mounted) setState(() {});
    });
  }

  void listenToTeams() {
    teamsStream?.cancel();
    teamsStream = firebaseService.getTeams().listen((teams) {
      allTeams = teams;
      generateGrid();
      if (mounted) setState(() {});
    });
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

        // Update Ghost Trail
        if (breadcrumbs.isEmpty || 
            locationService.calculateDistance(
              startLat: breadcrumbs.last.latitude,
              startLng: breadcrumbs.last.longitude,
              endLat: currentPosition.latitude,
              endLng: currentPosition.longitude) > 10) {
          breadcrumbs.add(currentPosition);
          if (breadcrumbs.length > 100) breadcrumbs.removeAt(0);
        }

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
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await firebaseService.regenerateStamina(user.uid);
        }
      },
    );
  }

  Future<void> _updatePlayerIcon(String url) async {
    try {
      if (url.isEmpty) {
        playerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
        return;
      }

      final response = await http.get(Uri.parse(url));
      final Uint8List bytes = response.bodyBytes;

      final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: 120, targetHeight: 120);
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image image = fi.image;

      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      const center = Offset(70, 70);
      const radius = 60.0;

      // Glow Ring
      final Paint glowPaint = Paint()
        ..color = Colors.cyan.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, radius + 4, glowPaint);

      // Border Ring
      final Paint borderPaint = Paint()..color = Colors.cyan;
      canvas.drawCircle(center, radius, borderPaint);

      // Clip for Image
      final Path clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius - 4));
      canvas.clipPath(clipPath);

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(center.dx - radius, center.dy - radius, radius * 2, radius * 2),
        Paint(),
      );

      final img = await pictureRecorder.endRecording().toImage(140, 140);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);

      if (mounted) {
        setState(() {
          playerIcon = BitmapDescriptor.bytes(data!.buffer.asUint8List());
        });
      }
    } catch (e) {
      debugPrint("Error creating avatar icon: $e");
      playerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }
  }

  void updateMarkers() {
    markers.clear();
    circles.clear();
    polylines.clear();

    // Player Marker
    markers.add(
      Marker(
        markerId: const MarkerId("player"),
        position: currentPosition,
        icon: playerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 5,
        flat: true,
      ),
    );

    // Ghost Trail (Breadcrumbs)
    if (breadcrumbs.length > 1) {
      polylines.add(Polyline(
        polylineId: const PolylineId("ghost_trail"),
        points: breadcrumbs,
        color: Colors.cyan.withValues(alpha: 0.3),
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    }

    // Bounty Tracker Line
    if (trackedBountyId != null) {
      try {
        final b = allBounties.firstWhere((element) => element.id == trackedBountyId);
        polylines.add(Polyline(
          polylineId: const PolylineId("nav_line"),
          points: [currentPosition, LatLng(b.latitude, b.longitude)],
          color: Colors.orange,
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ));
      } catch (_) {
        trackedBountyId = null;
      }
    }

    // Proximity Radar Ring (only if near bounty)
    for (var bounty in allBounties) {
      double dist = locationService.calculateDistance(
        startLat: currentPosition.latitude,
        startLng: currentPosition.longitude,
        endLat: bounty.latitude,
        endLng: bounty.longitude,
      );

        if (dist < 200) {
          circles.add(
            Circle(
              circleId: const CircleId("radar"),
              center: currentPosition,
              radius: 200,
              strokeWidth: 2,
              strokeColor: Colors.cyan.withValues(alpha: 0.3),
              fillColor: Colors.cyan.withValues(alpha: 0.05),
            ),
          );
          break; // Show only one radar ring
        }
    }

    // Bounty Markers
    for (var bounty in allBounties) {
      markers.add(
        Marker(
          markerId: MarkerId("bounty_${bounty.id}"),
          position: LatLng(bounty.latitude, bounty.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          onTap: () => showBountyDetails(bounty),
        ),
      );
    }

    // Stronghold Markers (Center of clusters)
    for (var team in allTeams) {
      for (var centerId in team.strongholdClusters) {
        LatLng centerPos = territoryService.getHexCenter(centerId);
        markers.add(
          Marker(
            markerId: MarkerId("stronghold_${team.id}_$centerId"),
            position: centerPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: "${team.name} Stronghold", snippet: "Strategic Defense Hub"),
          ),
        );
      }
    }
  }

  void showBountyDetails(BountyModel bounty) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double dist = locationService.calculateDistance(
          startLat: currentPosition.latitude,
          startLng: currentPosition.longitude,
          endLat: bounty.latitude,
          endLng: bounty.longitude,
        );

        double radiusMult = currentPlayer?.getModifier('bounty_radius', allGear) ?? 1.0;
        double effectiveRadius = 50 * radiusMult;

        bool canClaim = dist < effectiveRadius;

        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                "TACTICAL BOUNTY",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                "Recover this objective for rewards.",
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _rewardChip(Icons.add_circle_outline, "${bounty.xpReward} XP"),
                  if (bounty.itemReward != null)
                    _rewardChip(Icons.inventory_2_outlined, "GEAR CACHE"),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canClaim ? Colors.orange : Colors.grey[300],
                        foregroundColor: canClaim ? Colors.white : Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: canClaim ? () async {
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        navigator.pop();
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          // Bounty Claim costs 15 Stamina
                          bool hasStamina = await firebaseService.consumeStamina(user.uid, 15);
                          if (!hasStamina) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text("Insufficient Stamina to claim bounty!"),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          await firebaseService.claimBounty(user.uid, bounty);
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text("Bounty Claimed!"), backgroundColor: Colors.green),
                          );
                        }
                      } : null,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        canClaim ? "CLAIM" : "OUT OF RANGE",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                        foregroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: Colors.blueAccent, width: 1),
                      ),
                      onPressed: () {
                        setState(() {
                          trackedBountyId = bounty.id;
                          updateMarkers();
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text("TRACK", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              if (radiusMult > 1.0 && !canClaim)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    "Thermal Goggles Active (+${((radiusMult - 1) * 100).toInt()}% Range)",
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _rewardChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        ],
      ),
    );
  }

  void updatePlayerMarker() {
    updateMarkers();
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

    bool hasMegaRadar = player.activePowerUps.containsKey("radar") &&
        player.activePowerUps["radar"]!.isAfter(DateTime.now());

    if (!antiCheatService.canCapture(
      userIsWalking: isWalking,
      captureBlocked: captureBlocked,
      distanceToTileMeters: distToCenter,
      distanceMultiplier: hasMegaRadar ? 2.0 : 1.0,
    )) {
      return;
    }

    // Stamina Check: Capturing a tile costs 5 Stamina
    double agilityMult = player.getModifier('capture_stamina_mult', allGear);
    int baseCost = 5;
    int finalCost = (baseCost * (agilityMult == 1.0 ? 1.0 : agilityMult)).round();

    bool hasStamina = await firebaseService.consumeStamina(uid, finalCost);
    if (!hasStamina) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Insufficient Stamina! Rest to recover energy."),
            backgroundColor: Colors.orange,
          ),
        );
      }
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

    // FLOW STATE BONUS: 4.5 to 7.0 km/h is the sweet spot
    double flowMultiplier = (speedKmh >= 4.5 && speedKmh <= 7.0) ? 1.5 : 1.0;
    double gearMultiplier = player.getModifier('xp_mult', allGear);
    double stepXpMultiplier = player.getModifier('step_xp_mult', allGear);
    int baseXP = 15;
    int finalXP = (baseXP * flowMultiplier * gearMultiplier * stepXpMultiplier).toInt();

    await firebaseService.incrementXP(uid: player.uid, xpToAdd: finalXP);

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

    // SHIELD CHECK: Verify if target owner is shielded
    if (tile.ownerType == "solo") {
      final ownerDoc = await firebaseService.firestore.collection("players").doc(tile.ownerId).get();
      if (ownerDoc.exists) {
        final ownerData = PlayerModel.fromMap(ownerDoc.data()!);
        if (ownerData.activePowerUps.containsKey("shield") &&
            ownerData.activePowerUps["shield"]!.isAfter(DateTime.now())) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.blueGrey,
                content: Text("🛡️ TARGET SECURED: Territory Shield is Active!"),
              ),
            );
          }
          return;
        }
      }
    }

    // STRONGHOLD DEFENSE BONUS
    bool isStronghold = false;
    for (var team in allTeams) {
      if (team.id == tile.ownerId) {
        for (var centerId in team.strongholdClusters) {
          if (tile.tileId == centerId || territoryService.getNeighbors(centerId).contains(tile.tileId)) {
            isStronghold = true;
            break;
          }
        }
      }
    }

    int damage = 20 + (player.effectiveStrength ~/ 2);
    if (isStronghold) {
      damage = (damage / 2).floor();
    }

    int newPower = tile.power - damage;

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

    int repair = 10 + (player.effectiveEndurance ~/ 2);
    int newPower = (tile.power + repair).clamp(0, 100);

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
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        navigator.pop();
                        
                        // Check if it's a stronghold
                        bool isStronghold = false;
                        for (var team in allTeams) {
                          if (team.id == tile.ownerId) {
                            for (var centerId in team.strongholdClusters) {
                              if (tile.tileId == centerId || territoryService.getNeighbors(centerId).contains(tile.tileId)) {
                                isStronghold = true;
                                break;
                              }
                            }
                          }
                        }

                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;
                        final uid = user.uid;

                        // Attack costs 10 Stamina, Strongholds cost 20
                        int cost = isStronghold ? 20 : 10;
                        bool hasStamina = await firebaseService.consumeStamina(uid, cost);
                        if (!hasStamina) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text("Insufficient Stamina to attack!"), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        
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
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        navigator.pop();
                        
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;
                        final uid = user.uid;

                        // Fortify costs 10 Stamina
                        bool hasStamina = await firebaseService.consumeStamina(uid, 10);
                        if (!hasStamina) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text("Insufficient Stamina to fortify!"), backgroundColor: Colors.orange),
                          );
                          return;
                        }

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

      Set<String> strongholdTiles = {};
      for (var team in allTeams) {
        if (team.id == sampleTile.ownerId) {
          for (var clusterCenter in team.strongholdClusters) {
            strongholdTiles.add(clusterCenter);
            strongholdTiles.addAll(territoryService.getNeighbors(clusterCenter));
          }
        }
      }

      hexagons.addAll(territoryService.buildUnifiedTerritory(
        groupKey: key,
        tileIds: tileIds,
        color: territoryColor,
        strongholdTileIds: strongholdTiles,
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
    bountiesStream?.cancel();
    teamsStream?.cancel();
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
            circles: circles,
            polylines: polylines,
            myLocationEnabled: false, // Using custom marker instead
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
                        Row(
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
                            if (speedKmh >= 4.5 && speedKmh <= 7.0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "FLOW STATE: 1.5x XP",
                                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
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
