import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/player_model.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'armory_screen.dart';
import 'daily_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showUpdateAvatarDialog(BuildContext context, String uid) {
    final controller = TextEditingController();
    final ImagePicker picker = ImagePicker();
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text("UPDATE AVATAR", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUpdating) ...[
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.blueAccent),
                        SizedBox(height: 16),
                        Text("UPLOADING ASSETS...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent)),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text("DIRECT UPLOAD", style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5F7FA),
                            foregroundColor: Colors.blueAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                            if (image != null) {
                              setDialogState(() => isUpdating = true);
                              final bytes = await image.readAsBytes();
                              final url = await FirebaseService().uploadAvatarFile(uid, bytes);
                              if (url != null) {
                                await FirebaseService().updateAvatar(uid: uid, avatarUrl: url);
                                if (context.mounted) Navigator.pop(context);
                              } else {
                                setDialogState(() => isUpdating = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Upload failed. Please check your connection or permissions.")),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.photo_library_rounded, size: 18),
                          label: const Text("GALLERY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5F7FA),
                            foregroundColor: Colors.blueAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                            if (image != null) {
                              setDialogState(() => isUpdating = true);
                              final bytes = await image.readAsBytes();
                              final url = await FirebaseService().uploadAvatarFile(uid, bytes);
                              if (url != null) {
                                await FirebaseService().updateAvatar(uid: uid, avatarUrl: url);
                                if (context.mounted) Navigator.pop(context);
                              } else {
                                setDialogState(() => isUpdating = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Upload failed. Please check your connection.")),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: const Text("CAMERA", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("OR ENTER IMAGE URL", style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    enabled: !isUpdating,
                    decoration: InputDecoration(
                      hintText: "https://example.com/photo.jpg",
                      hintStyle: const TextStyle(color: Colors.black26),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: isUpdating ? [] : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (controller.text.isNotEmpty) {
                    setDialogState(() => isUpdating = true);
                    await FirebaseService().updateAvatar(uid: uid, avatarUrl: controller.text);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text("UPDATE URL", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBiometricsModal(BuildContext context, PlayerModel player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BiometricsEditorSheet(player: player),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(
          child: Text(
            "User Not Logged In",
            style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return StreamBuilder<PlayerModel?>(
      stream: FirebaseService().getPlayerStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7FA),
            body: Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Player Profile Not Found",
                    style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseService().ensurePlayerProfileExists(
                        user.uid,
                        user.email ?? "unknown@fitquest.io",
                        user.displayName ?? "Operator ${user.uid.substring(0, 5)}",
                      );
                    },
                    child: const Text("INITIALIZE PROFILE"),
                  ),
                ],
              ),
            ),
          );
        }

        final player = snapshot.data!;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              "PLAYER PROFILE",
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 1.5, fontSize: 18),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                        ),
                      ),
                      child: CustomPaint(
                        painter: _GridPainter(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 104,
                                  height: 104,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Colors.blueAccent, Colors.cyanAccent],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blueAccent.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: CircleAvatar(
                                    radius: 46,
                                    backgroundColor: const Color(0xFFF5F7FA),
                                    backgroundImage: player.avatar.isNotEmpty ? NetworkImage(player.avatar) : null,
                                    child: player.avatar.isEmpty ? const Icon(Icons.person_rounded, size: 55, color: Colors.blueAccent) : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _showUpdateAvatarDialog(context, player.uid),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              player.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            if (player.characterClass != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                player.characterClass!.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.blueAccent.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "LVL ${player.level}",
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  FirebaseService().getRankTitle(player.level).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "EXPERIENCE POINTS",
                                      style: TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                                    ),
                                    Text(
                                      "${player.xp % 1000} / 1000",
                                      style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: (player.xp % 1000) / 1000,
                                    minHeight: 8,
                                    backgroundColor: Colors.black.withValues(alpha: 0.05),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "CORE ATTRIBUTES",
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _attributeCard(label: "STRENGTH", value: player.effectiveStrength, icon: Icons.fitness_center_rounded, color: Colors.redAccent)),
                          const SizedBox(width: 12),
                          Expanded(child: _attributeCard(label: "AGILITY", value: player.effectiveAgility, icon: Icons.bolt_rounded, color: Colors.cyan)),
                          const SizedBox(width: 12),
                          Expanded(child: _attributeCard(label: "ENDURANCE", value: player.effectiveEndurance, icon: Icons.shield_rounded, color: Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  "STAMINA RESERVE",
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black54, letterSpacing: 1),
                                ),
                                const Spacer(),
                                Text(
                                  "${player.currentStamina}/${player.maxStamina}",
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: player.maxStamina > 0 ? (player.currentStamina / player.maxStamina) : 0,
                                minHeight: 12,
                                backgroundColor: Colors.amber.withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "PLAYER SETTINGS",
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 16),
                      _profileActionTile(
                        context,
                        title: "FITNESS TARGETS",
                        subtitle: "SET YOUR GOALS & PREFERENCES",
                        icon: Icons.monitor_heart_rounded,
                        color: Colors.teal,
                        onTap: () => _showBiometricsModal(context, player),
                      ),
                      const SizedBox(height: 12),
                      _profileActionTile(
                        context,
                        title: "EQUIPMENT ROOM",
                        subtitle: "MANAGE GEAR & EQUIPMENT",
                        icon: Icons.shield_rounded,
                        color: Colors.blueAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ArmoryScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _profileActionTile(
                        context,
                        title: "ACTIVITY HISTORY",
                        subtitle: "VIEW PAST STEPS & PROGRESS",
                        icon: Icons.history_rounded,
                        color: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => DailyHistoryScreen(player: player)),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "FITNESS STATS",
                        style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                        children: [
                          _compactStatTile(
                            label: "DAILY STEPS",
                            value: player.dailySteps.toString(),
                            target: "/ ${player.dailyStepTarget}",
                            icon: Icons.directions_walk_rounded,
                            color: Colors.blueAccent,
                          ),
                          _compactStatTile(
                            label: "TERRITORY",
                            value: player.totalLand.toString(),
                            target: "AREAS",
                            icon: Icons.grid_view_rounded,
                            color: Colors.green,
                          ),
                          _compactStatTile(
                            label: "STABILITY",
                            value: "${player.trustScore}%",
                            target: "RATING",
                            icon: Icons.verified_user_rounded,
                            color: Colors.purple,
                          ),
                          _compactStatTile(
                            label: "TEAM",
                            value: player.team,
                            target: "AFFILIATION",
                            icon: Icons.groups_rounded,
                            color: Colors.teal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _achievementSection(player),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                                    (route) => false,
                              );
                            }
                          },
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text("SIGN OUT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attributeCard({required String label, required int value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _compactStatTile({required String label, required String value, required String target, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            target,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _achievementSection(PlayerModel player) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                "ACHIEVEMENTS",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _achievementTile(
            icon: Icons.directions_run_rounded,
            title: "Apex Strider",
            subtitle: "10,000+ Cumulative Steps",
            isUnlocked: player.totalSteps >= 10000,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 0.5),
          ),
          _achievementTile(
            icon: Icons.map_rounded,
            title: "Explorer",
            subtitle: "Capture 50+ Areas",
            isUnlocked: player.totalLand >= 50,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 0.5),
          ),
          _achievementTile(
            icon: Icons.military_tech_rounded,
            title: "Master Player",
            subtitle: "Reach Player Level 10",
            isUnlocked: player.level >= 10,
          ),
        ],
      ),
    );
  }

  Widget _achievementTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isUnlocked,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: isUnlocked ? Colors.orange.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          child: Icon(icon, color: isUnlocked ? Colors.orange : Colors.black26, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: isUnlocked ? Colors.black87 : Colors.black38,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isUnlocked ? Colors.black54 : Colors.black26,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          isUnlocked ? Icons.check_circle_outline_rounded : Icons.lock_outline_rounded,
          color: isUnlocked ? Colors.green : Colors.black12,
          size: 22,
        ),
      ],
    );
  }

  Widget _profileActionTile(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.3), size: 18),
          ],
        ),
      ),
    );
  }
}

class _BiometricsEditorSheet extends StatefulWidget {
  final PlayerModel player;
  const _BiometricsEditorSheet({required this.player});

  @override
  State<_BiometricsEditorSheet> createState() => _BiometricsEditorSheetState();
}

class _BiometricsEditorSheetState extends State<_BiometricsEditorSheet> {
  late double _height;
  late double _weight;
  late String _goal;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _height = widget.player.heightCm ?? 170.0;
    _weight = widget.player.weightKg ?? 65.0;
    _goal = widget.player.fitnessGoal ?? "maintenance";
  }

  Map<String, dynamic> _computeMatrix() {
    double meters = _height / 100;
    double bmi = _weight / (meters * meters);

    if (bmi < 18.5) {
      return {"bmi": bmi, "tier": "UNDERWEIGHT", "steps": 6000, "mins": 20, "color": Colors.blue};
    } else if (bmi < 25.0) {
      return {"bmi": bmi, "tier": "NORMAL WEIGHT", "steps": 10000, "mins": 30, "color": Colors.green};
    } else if (bmi < 30.0) {
      return {"bmi": bmi, "tier": "OVERWEIGHT", "steps": 12000, "mins": 45, "color": Colors.orange};
    } else {
      return {"bmi": bmi, "tier": "OBESE", "steps": 8000, "mins": 30, "color": Colors.redAccent};
    }
  }

  Widget _buildGoalChip(String id, String label) {
    bool selected = _goal == id;
    return GestureDetector(
      onTap: () => setState(() => _goal = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blueAccent : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.blueAccent : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matrix = _computeMatrix();

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("UPDATE FITNESS STATS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87, letterSpacing: 0.5)),
              if (_isSaving) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
            ],
          ),
          const SizedBox(height: 24),
          const Text("FITNESS GOAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildGoalChip("weight_loss", "Weight Loss"),
                const SizedBox(width: 8),
                _buildGoalChip("muscle_gain", "Muscle Gain"),
                const SizedBox(width: 8),
                _buildGoalChip("endurance", "Endurance"),
                const SizedBox(width: 8),
                _buildGoalChip("maintenance", "Maintenance"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text("HEIGHT: ${_height.toStringAsFixed(0)} CM", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
          Slider(
            value: _height,
            min: 120,
            max: 220,
            activeColor: Colors.blueAccent,
            inactiveColor: const Color(0xFFF5F7FA),
            onChanged: _isSaving ? null : (val) => setState(() => _height = val),
          ),
          const SizedBox(height: 12),
          Text("WEIGHT: ${_weight.toStringAsFixed(1)} KG", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
          Slider(
            value: _weight,
            min: 40,
            max: 150,
            activeColor: Colors.blueAccent,
            inactiveColor: const Color(0xFFF5F7FA),
            onChanged: _isSaving ? null : (val) => setState(() => _weight = val),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (matrix['color'] as Color).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (matrix['color'] as Color).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(matrix['tier'], style: TextStyle(color: matrix['color'], fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text("BMI: ${(matrix['bmi'] as double).toStringAsFixed(1)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("🎯 ${matrix['steps']} STEPS/DAY", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("⏱️ ${matrix['mins']} MIN ACTIVE", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isSaving ? null : () async {
                setState(() => _isSaving = true);
                try {
                  await FirebaseService().updateBiometrics(
                    uid: widget.player.uid,
                    heightCm: _height,
                    weightKg: _weight,
                    fitnessGoal: _goal,
                    stepTarget: matrix['steps'],
                    exerciseTarget: matrix['mins'],
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  setState(() => _isSaving = false);
                }
              },
              child: const Text("SAVE FITNESS GOALS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          )
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
