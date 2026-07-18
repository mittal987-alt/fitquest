import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../services/location_service.dart';
import '../services/pedometer_service.dart';
import '../services/territory_service.dart';
import '../services/anti_cheat_service.dart';
import '../services/firebase_service.dart';
import '../services/treasure_service.dart';
import '../models/hex_tile_model.dart';
import '../models/player_model.dart';
import '../models/bounty_model.dart';
import '../models/team_model.dart';
import '../models/gear_model.dart';
import '../models/anomaly_model.dart';
import '../models/world_event_model.dart';
import '../config/crafting_recipes.dart';
import 'hacking_minigame_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  GoogleMapController? mapController;
  final LocationService locationService = LocationService();
  final PedometerService pedometerService = PedometerService();
  final TerritoryService territoryService = TerritoryService();
  final AntiCheatService antiCheatService = AntiCheatService();
  final FirebaseService firebaseService = FirebaseService();
  final TreasureService treasureService = TreasureService();

  StreamSubscription<Position>? positionStream;
  StreamSubscription<List<HexTileModel>>? hexTilesStream;
  StreamSubscription<List<BountyModel>>? bountiesStream;
  StreamSubscription<List<TeamModel>>? teamsStream;
  StreamSubscription<List<AnomalyModel>>? anomaliesStream;
  StreamSubscription<List<WorldEventModel>>? worldEventsStream;

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
  List<AnomalyModel> allAnomalies = [];
  List<WorldEventModel> allWorldEvents = [];
  List<LatLng> treasureChests = [];
  List<LatLng> mineralNodes = []; // Rare material mining nodes
  PlayerModel? currentPlayer;

  AnomalyModel? scanningAnomaly;
  double anomalyScanProgress = 0.0;
  StreamSubscription<TacticalPulse>? pulseSubscription;
  StreamSubscription<PlayerModel?>? playerStream;
  StreamSubscription<List<GearModel>>? gearStream;

  BitmapDescriptor? playerIcon;
  String? lastAvatarUrl;

  double speedKmh = 0;
  String? lastCapturedTile;
  String? _mapStyleJson;

  Set<String> myOwnedTileIds = {};

  // Animation controllers for territory capture
  late AnimationController _captureAnimController;
  late Animation<double> _captureScale;
  late Animation<double> _captureOpacity;
  bool _showCaptureOverlay = false;
  String _lastCaptureMsg = "";

  // FIX: was never stored, so it could only ever self-cancel on its *next*
  // scheduled tick after dispose (up to 2 minutes late) instead of
  // immediately. Now cancelled explicitly in dispose(), same as every other
  // subscription in this file.
  Timer? _regenTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadMapStyle();
    initializeLocation();
    listenToHexTiles();
    listenToBounties();
    listenToTeams();
    listenToAnomalies();
    listenToWorldEvents();
    listenToPlayer();
    listenToGear();
    startRegenLoop();
    _spawnTreasure();
    _spawnMineralNodes();
  }

  void _spawnMineralNodes() {
    if (currentPosition != const LatLng(28.6139, 77.2090)) {
      final random = Random();
      setState(() {
        mineralNodes = List.generate(3, (index) {
          double latOffset = (random.nextDouble() - 0.5) * 0.005;
          double lngOffset = (random.nextDouble() - 0.5) * 0.005;
          return LatLng(currentPosition.latitude + latOffset, currentPosition.longitude + lngOffset);
        });
      });
    }
  }

  void _spawnTreasure() {
    if (currentPosition != const LatLng(28.6139, 77.2090)) {
      setState(() {
        treasureChests = treasureService.spawnChests(currentPosition, 5);
      });
    }
  }

  void _initAnimations() {
    _captureAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _captureScale = CurvedAnimation(
      parent: _captureAnimController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
    );

    _captureOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_captureAnimController);
  }

  void _triggerCaptureAnimation(String message) {
    if (mounted) {
      setState(() {
        _lastCaptureMsg = message;
        _showCaptureOverlay = true;
      });
      _captureAnimController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() => _showCaptureOverlay = false);
        }
      });
    }
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

  void listenToAnomalies() {
    anomaliesStream?.cancel();
    anomaliesStream = firebaseService.getAnomalies().listen((anomalies) {
      if (mounted) {
        setState(() {
          allAnomalies = anomalies;
          updateMarkers();
        });
      }
    });
  }

  void listenToWorldEvents() {
    worldEventsStream?.cancel();
    worldEventsStream = firebaseService.getWorldEvents().listen((events) {
      if (mounted) {
        setState(() {
          allWorldEvents = events;
          updateMarkers();
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
          .loadString('assets/map_style.json');
      if (mounted) {
        setState(() {
          _mapStyleJson = style;
        });
      }
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
        // FIX: was `user.isAnonymous ? "anon" : user.uid` — tiles are always
        // saved with the real Firebase uid (see captureTile(), which never
        // special-cases anonymous users), so this literal "anon" string never
        // matched anything, meaning anonymous/guest players' own territory
        // was always computed as empty here.
        String myUid = user.uid;
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
    _spawnTreasure();
    startTracking();
    if (mounted) setState(() {});
  }

  Position? lastPosition;
  DateTime? lastTimestamp;

  void startTracking() {
    positionStream?.cancel();
    pulseSubscription?.cancel();

    // Subscribe to TacticalPulse for Anomaly Scanning
    pulseSubscription = pedometerService.tacticalPulseStream.listen((pulse) {
      if (mounted && scanningAnomaly != null) {
        setState(() {
          anomalyScanProgress += pulse.scanProgress;
          if (anomalyScanProgress >= 1.0) {
            _completeAnomalyScan();
          }
        });
      }
    });

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
                  content: Text("Moving too fast! Territory capture paused."),
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
          // Cancel any active anomaly scan if user enters a vehicle
          if (scanningAnomaly != null) {
            setState(() {
              scanningAnomaly = null;
              anomalyScanProgress = 0.0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Signal Interrupted: Anomaly detection requires walking speed!"),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
        }

        if (isWalking) {
          antiCheatService.resetCaptureBlock();
          await captureTile();
        }

        updatePlayerMarker();
        generateGrid();
        _checkAnomalyProximity();

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
    _regenTimer?.cancel();
    _regenTimer = Timer.periodic(
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

  void _checkAnomalyProximity() {
    if (scanningAnomaly != null) {
      if (antiCheatService.isVehicle(speedKmh)) {
        setState(() {
          scanningAnomaly = null;
          anomalyScanProgress = 0.0;
        });
        return;
      }

      double dist = locationService.calculateDistance(
        startLat: currentPosition.latitude,
        startLng: currentPosition.longitude,
        endLat: scanningAnomaly!.position.latitude,
        endLng: scanningAnomaly!.position.longitude,
      );
      if (dist > 50) {
        setState(() {
          scanningAnomaly = null;
          anomalyScanProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Signal Lost: Too far from anomaly!"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _completeAnomalyScan() async {
    if (scanningAnomaly == null || currentPlayer == null) return;

    final anomaly = scanningAnomaly!;
    setState(() {
      scanningAnomaly = null;
      anomalyScanProgress = 0.0;
    });

    await firebaseService.claimAnomaly(currentPlayer!.uid, anomaly);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Mystery Discovery Unlocked: ${anomaly.type} rewards acquired!"),
          backgroundColor: Colors.cyan,
        ),
      );
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

    // Anomaly Markers
    for (var anomaly in allAnomalies) {
      markers.add(
        Marker(
          markerId: MarkerId("anomaly_${anomaly.id}"),
          position: anomaly.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          onTap: () => _showAnomalyDetails(anomaly),
        ),
      );
    }

    // Treasure Markers
    for (int i = 0; i < treasureChests.length; i++) {
      markers.add(
        Marker(
          markerId: MarkerId("treasure_$i"),
          position: treasureChests[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          onTap: () => _showTreasureDetails(treasureChests[i], i),
        ),
      );
    }

    // Mineral Node Markers
    for (int i = 0; i < mineralNodes.length; i++) {
      markers.add(
        Marker(
          markerId: MarkerId("mineral_$i"),
          position: mineralNodes[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => _showMineralNodeDetails(mineralNodes[i], i),
        ),
      );
    }

    // World Event Markers
    for (var event in allWorldEvents) {
      markers.add(
        Marker(
          markerId: MarkerId("world_event_${event.id}"),
          position: event.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          onTap: () => _showWorldEventDetails(event),
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

  void _showAnomalyDetails(AnomalyModel anomaly) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double dist = locationService.calculateDistance(
          startLat: currentPosition.latitude,
          startLng: currentPosition.longitude,
          endLat: anomaly.position.latitude,
          endLng: anomaly.position.longitude,
        );

        bool canScan = dist < 50;

        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Icon(Icons.radar_rounded, size: 64, color: Color(0xFF8E2DE2)),
              const SizedBox(height: 16),
              Text(
                "MYSTERY ${anomaly.type.toUpperCase()}",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                "Keep moving to unlock these rewards.",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              if (canScan)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      setState(() {
                        scanningAnomaly = anomaly;
                        anomalyScanProgress = 0.0;
                      });
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text("START UNLOCKING", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                )
              else
                Text(
                  "Located ${dist.toStringAsFixed(0)}m away. Move within 50m to start unlocking.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showTreasureDetails(LatLng position, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double dist = locationService.calculateDistance(
          startLat: currentPosition.latitude,
          startLng: currentPosition.longitude,
          endLat: position.latitude,
          endLng: position.longitude,
        );

        bool canClaim = dist < 30;

        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Icon(Icons.inventory_2_rounded, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              const Text(
                "TREASURE CACHE",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                "A forgotten supply crate has been detected.",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              if (canClaim)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.amber, Colors.orange],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (currentPlayer != null) {
                        await treasureService.claimChest(currentPlayer!.uid, "common");
                        setState(() {
                          treasureChests.removeAt(index);
                          updateMarkers();
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Treasure Claimed! XP and Materials added."),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text("CLAIM TREASURE", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                )
              else
                Text(
                  "Located ${dist.toStringAsFixed(0)}m away. Move within 30m to open.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showMineralNodeDetails(LatLng position, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double dist = locationService.calculateDistance(
          startLat: currentPosition.latitude,
          startLng: currentPosition.longitude,
          endLat: position.latitude,
          endLng: position.longitude,
        );

        bool canMine = dist < 30;

        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Icon(Icons.settings_input_component_rounded, size: 64, color: Colors.greenAccent),
              const SizedBox(height: 16),
              const Text(
                "RARE MINERAL NODE",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                "Extraction site for Silicon, Nanites, and Energy Cores.",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              if (canMine)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.greenAccent, Colors.teal],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (currentPlayer != null) {
                        final materials = [
                          CraftingRecipes.materialSilicon,
                          CraftingRecipes.materialNanites,
                          CraftingRecipes.materialEnergyCore
                        ];
                        final randomMat = materials[Random().nextInt(materials.length)];
                        
                        // Update inventory via firebase
                        Map<String, int> inv = Map<String, int>.from(currentPlayer!.inventory);
                        inv[randomMat] = (inv[randomMat] ?? 0) + 1;
                        await firebaseService.firestore.collection("players").doc(currentPlayer!.uid).update({
                          "inventory": inv,
                          "xp": FieldValue.increment(50),
                        });

                        setState(() {
                          mineralNodes.removeAt(index);
                          updateMarkers();
                        });
                        
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Mined 1x ${randomMat.toUpperCase()}!"),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.precision_manufacturing_rounded),
                    label: const Text("EXTRACT MATERIALS", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                )
              else
                Text(
                  "Located ${dist.toStringAsFixed(0)}m away. Move within 30m to mine.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showWorldEventDetails(WorldEventModel event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double dist = locationService.calculateDistance(
          startLat: currentPosition.latitude,
          startLng: currentPosition.longitude,
          endLat: event.position.latitude,
          endLng: event.position.longitude,
        );

        bool canParticipate = dist < 100;

        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Icon(Icons.public_rounded, size: 64, color: Colors.deepPurpleAccent),
              const SizedBox(height: 16),
              Text(
                event.title.toUpperCase(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              const Text(
                "TEAM LEADERBOARD",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 1),
              ),
              const SizedBox(height: 12),
              ...event.teamContributions.entries.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("TEAM ${e.key.substring(0, 5)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text("${e.value} PT", style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.w900)),
                  ],
                ),
              )),
              const SizedBox(height: 24),
              if (canParticipate)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: event.eventType == "Data Breach" 
                        ? [Colors.cyanAccent, Colors.blueAccent]
                        : [Colors.deepPurpleAccent, Colors.blueAccent],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (currentPlayer != null && currentPlayer!.teamId != null) {
                        if (event.eventType == "Data Breach") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HackingMinigameScreen(
                                eventId: event.id,
                                teamId: currentPlayer!.teamId!,
                                uid: currentPlayer!.uid,
                                onComplete: (success) async {
                                  if (success) {
                                    await firebaseService.contributeToWorldEvent(
                                      event.id, 
                                      currentPlayer!.teamId!, 
                                      currentPlayer!.uid,
                                      bonus: 5,
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        } else {
                          await firebaseService.contributeToWorldEvent(
                            event.id, 
                            currentPlayer!.teamId!, 
                            currentPlayer!.uid,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Contribution registered! Team rank updated."),
                                backgroundColor: Colors.deepPurpleAccent,
                              ),
                            );
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Join a team to participate in world events!")),
                        );
                      }
                    },
                    icon: Icon(event.eventType == "Data Breach" ? Icons.terminal_rounded : Icons.flash_on_rounded),
                    label: Text(
                      event.eventType == "Data Breach" ? "INITIALIZE BREACH" : "CONTRIBUTE (10 STAMINA)", 
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                )
              else
                Text(
                  "Located ${dist.toStringAsFixed(0)}m away. Move within 100m to participate.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        );
      },
    );
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
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Icon(Icons.stars_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                "BOUNTY GOAL",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                "Reach this goal for rewards.",
                style: TextStyle(fontSize: 16, color: Colors.white70),
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
                    child: Container(
                      decoration: canClaim ? BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ) : null,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canClaim ? Colors.transparent : Colors.white10,
                          foregroundColor: canClaim ? Colors.white : Colors.white38,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: canClaim ? () async {
                          if (antiCheatService.isVehicle(speedKmh)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Action Blocked: Cannot claim bounties in a vehicle!"),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: Colors.white24, width: 1),
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
                    style: const TextStyle(color: Color(0xFF8E2DE2), fontSize: 11, fontWeight: FontWeight.bold),
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
        color: const Color(0xFF8E2DE2).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8E2DE2).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF8E2DE2)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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

    // ENERGY BOOST BONUS
    // FIX: was hardcoded to 1.5 whenever energy_boost was active. Every other
    // place in the app that applies this buff (firebase_service.dart's
    // incrementXP, for example) uses the player's actual computed
    // energyBoostXpMultiplier, which varies by fitness tier/goal (1.2x-2.2x+),
    // not a flat 1.5x. Territory-capture XP was the one activity giving a
    // different (and often wrong) bonus for the same buff.
    double energyBoostMultiplier = 1.0;
    if (player.activePowerUps.containsKey("energy_boost")) {
      DateTime expiry = player.activePowerUps["energy_boost"]!;
      if (expiry.isAfter(DateTime.now())) {
        energyBoostMultiplier = player.energyBoostXpMultiplier.toDouble();
      }
    }

    double gearMultiplier = player.getModifier('xp_mult', allGear);
    double stepXpMultiplier = player.getModifier('step_xp_mult', allGear);
    int baseXP = 15;
    int finalXP = (baseXP * flowMultiplier * energyBoostMultiplier * gearMultiplier * stepXpMultiplier).toInt();

    await firebaseService.incrementXP(uid: player.uid, xpToAdd: finalXP);

    _triggerCaptureAnimation("TERRITORY SECURED");

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
      if (!mounted) return;
      if (ownerDoc.exists) {
        final ownerData = PlayerModel.fromMap(ownerDoc.data()!);
        if (ownerData.activePowerUps.containsKey("shield") &&
            ownerData.activePowerUps["shield"]!.isAfter(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.blueGrey,
              content: Text("🛡️ PROTECTED: Territory Shield is Active!"),
            ),
          );
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

      _triggerCaptureAnimation("SECTOR NEUTRALIZED");
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

  Widget _mapFloatingButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF161B22).withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _statMini(IconData icon, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
      ],
    );
  }

  void _showMapDetailsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text("TODAY'S WALK", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricLarge(Icons.directions_walk_rounded, "${currentPlayer?.dailySteps ?? 0}", "Steps"),
                _metricLarge(Icons.straighten_rounded, "${currentPlayer?.dailyDistance.toStringAsFixed(1)}", "km"),
                _metricLarge(Icons.explore_rounded, "${(currentPlayer?.totalLand ?? 0) * 0.025}", "km² Area"),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("CLOSE DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricLarge(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF8E2DE2), size: 32),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  void showTileDetails(HexTileModel tile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    tile.ownerType == "solo" ? Icons.person_rounded : Icons.groups_rounded,
                    size: 36,
                    color: const Color(0xFF8E2DE2),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      tile.ownerName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tile.ownerType == "solo" ? "⚔️ Player Territory" : "🛡️ Team Territory",
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white54, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Defense Strength", style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold)),
                  Text("XP REWARD: 100", style: TextStyle(fontSize: 12, color: Color(0xFF8E2DE2), fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LinearProgressIndicator(
                  value: tile.power / 100,
                  minHeight: 12,
                  backgroundColor: Colors.white10,
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
                          if (navigator.mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text("Insufficient Stamina to attack!"), backgroundColor: Colors.orange),
                            );
                          }
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
                        backgroundColor: const Color(0xFF8E2DE2).withValues(alpha: 0.1),
                        foregroundColor: const Color(0xFF8E2DE2),
                        elevation: 0,
                        side: BorderSide(color: const Color(0xFF8E2DE2).withValues(alpha: 0.2), width: 1.5),
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
                          if (navigator.mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text("Insufficient Stamina to fortify!"), backgroundColor: Colors.orange),
                            );
                          }
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
          final tile = tiles.firstWhere(
                (t) => t.tileId == tileId,
            orElse: () => HexTileModel(
              tileId: tileId,
              latitude: 0.0,
              longitude: 0.0,
              ownerType: "neutral",
              ownerId: "",
              ownerName: "Neutral Territory",
              color: "grey",
              power: 0,
              capturedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
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
    anomaliesStream?.cancel();
    worldEventsStream?.cancel();
    pulseSubscription?.cancel();
    _captureAnimController.dispose();
    // FIX: these two were started in initState() (listenToPlayer(),
    // listenToGear()) but never cancelled here, unlike every other
    // subscription in this file — a real leak once this screen's owning
    // widget is actually disposed (e.g. on sign-out).
    playerStream?.cancel();
    gearStream?.cancel();
    _regenTimer?.cancel();
    super.dispose();
  }

  Widget _buildTerritoryStats() {
    return Positioned(
      top: 100,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _statBadge(Icons.landscape, "${allTiles.length} SECTORS"),
          const SizedBox(height: 8),
          _statBadge(Icons.group, "${allTiles.where((t) => t.ownerType == 'team').length} TEAM-OWNED"),
        ],
      ),
    );
  }

  Widget _statBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
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
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            onMapCreated: (controller) {
              mapController = controller;
            },
          ),
          _buildTerritoryStats(),

          // Top Header Overlay for Map Info
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFF8E2DE2), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "SECTOR ${territoryService.getHexId(currentPosition.latitude, currentPosition.longitude).substring(0, 6)}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _mapFloatingButton(Icons.layers_rounded, () {
                      // Layer toggle logic could go here
                    }),
                    const SizedBox(width: 12),
                    _mapFloatingButton(Icons.my_location_rounded, () {
                      if (mapController != null) {
                        mapController!.animateCamera(CameraUpdate.newLatLng(currentPosition));
                      }
                    }),
                  ],
                ),
              ],
            ),
          ),

          if (_showCaptureOverlay)
            Center(
              child: FadeTransition(
                opacity: _captureOpacity,
                child: ScaleTransition(
                  scale: _captureScale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8E2DE2).withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.security_rounded, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _lastCaptureMsg,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const Text(
                          "+ XP GAINED",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (scanningAnomaly != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("UNLOCKING MYSTERY", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                        Text("${(anomalyScanProgress * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: anomalyScanProgress,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(Colors.cyanAccent),
                    ),
                    const SizedBox(height: 8),
                    const Text("Physical movement required to unlock this reward.", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
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
                        "MOVING TOO FAST! Territory capture paused.",
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
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity! < -300) {
                  _showMapDetailsSheet();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E2DE2).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            speedKmh > 1.0 ? Icons.directions_run_rounded : Icons.accessibility_new_rounded,
                            color: const Color(0xFF8E2DE2),
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
                                      color: Colors.white,
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
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "FLOW STATE",
                                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "${speedKmh.toStringAsFixed(1)} KM/H",
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _statMini(Icons.directions_walk_rounded, "${currentPlayer?.dailySteps ?? 0}"),
                        const SizedBox(width: 16),
                        _statMini(Icons.straighten_rounded, "${currentPlayer?.dailyDistance.toStringAsFixed(1)}"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}