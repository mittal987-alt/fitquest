import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/walk_session_model.dart';
import '../models/player_model.dart';
import '../services/firebase_service.dart';

class WalkSummaryScreen extends StatefulWidget {
  final WalkSessionModel session;
  final PlayerModel? player;

  const WalkSummaryScreen({super.key, required this.session, this.player});

  @override
  State<WalkSummaryScreen> createState() => _WalkSummaryScreenState();
}

class _WalkSummaryScreenState extends State<WalkSummaryScreen> {
  static const Color _kBgColor = Color(0xFFF5F7FA);
  static const Color _kPrimaryPurple = Colors.blueAccent;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    final style = await rootBundle.loadString('assets/map_style.json');
    if (mounted) {
      setState(() {
        _mapStyle = style;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
                  ),
                  Expanded(
                    child: Text(
                      "MISSION COMPLETE",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      "WELL DONE, STRIDER",
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "${widget.session.steps} STEPS",
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 48, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 24),
                    _buildMiniMap(colorScheme),
                    const SizedBox(height: 32),
                    _buildStatsRow(colorScheme),
                    const SizedBox(height: 40),
                    if (widget.session.memories.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "WALK MEMORIES",
                          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMemoriesGrid(),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (widget.player?.isInTeam ?? false) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _shareToTeam(context),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text("SHARE TO TEAM CHAT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.cyanAccent,
                          side: const BorderSide(color: Colors.cyanAccent, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("RETURN TO BASE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMap(ColorScheme colorScheme) {
    if (widget.session.memories.isEmpty) return const SizedBox.shrink();

    final markers = widget.session.memories.map((m) {
      return Marker(
        markerId: MarkerId(m.timestamp.toString()),
        position: LatLng(m.latitude, m.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      );
    }).toSet();

    final initialPos = LatLng(
      widget.session.memories.first.latitude,
      widget.session.memories.first.longitude,
    );

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: initialPos, zoom: 15),
          markers: markers,
          style: _mapStyle,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          rotateGesturesEnabled: false,
          scrollGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomGesturesEnabled: false,
          onMapCreated: (controller) {
            if (widget.session.memories.length > 1) {
              double minLat = widget.session.memories.first.latitude;
              double maxLat = widget.session.memories.first.latitude;
              double minLng = widget.session.memories.first.longitude;
              double maxLng = widget.session.memories.first.longitude;

              for (var m in widget.session.memories) {
                if (m.latitude < minLat) minLat = m.latitude;
                if (m.latitude > maxLat) maxLat = m.latitude;
                if (m.longitude < minLng) minLng = m.longitude;
                if (m.longitude > maxLng) maxLng = m.longitude;
              }

              controller.animateCamera(
                CameraUpdate.newLatLngBounds(
                  LatLngBounds(
                    southwest: LatLng(minLat, minLng),
                    northeast: LatLng(maxLat, maxLng),
                  ),
                  40,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _shareToTeam(BuildContext context) async {
    if (widget.player == null || !widget.player!.isInTeam || widget.player!.teamId == null) return;

    final service = FirebaseService();
    final kcal = (widget.session.steps * 0.04).toInt();
    final duration = widget.session.endTime.difference(widget.session.startTime).inMinutes;
    
    final message = "🚀 MISSION COMPLETE!\n"
        "Captured ${widget.session.steps} steps ($kcal kcal) over ${widget.session.distanceKm.toStringAsFixed(2)} km.\n"
        "Duration: $duration mins.";

    try {
      await service.sendTeamChatMessage(
        widget.player!.teamId!,
        widget.player!.uid,
        widget.player!.name,
        message,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("RESULTS SHARED TO TEAM CHAT!"),
            backgroundColor: Colors.cyan,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to share: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatsRow(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statItem(colorScheme, widget.session.distanceKm.toStringAsFixed(2), "KM", Icons.straighten_rounded),
        _statItem(colorScheme, "${(widget.session.steps * 0.04).toInt()}", "KCAL", Icons.local_fire_department_rounded),
        _statItem(colorScheme, "${widget.session.endTime.difference(widget.session.startTime).inMinutes}", "MINS", Icons.timer_rounded),
      ],
    );
  }

  Widget _statItem(ColorScheme colorScheme, String value, String unit, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: colorScheme.primary, size: 24),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(unit, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMemoriesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widget.session.memories.length,
      itemBuilder: (context, index) {
        final memory = widget.session.memories[index];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(memory.imageUrl), fit: BoxFit.cover),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    child: Text(
                      memory.caption,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
