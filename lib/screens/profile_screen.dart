import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/player_model.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'armory_screen.dart';
import 'activity_screen.dart';

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
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7FA),
            body: Center(
              child: Text(
                "Player Profile Not Found",
                style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
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
              "OPERATOR PROFILE",
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 1.5, fontSize: 18),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blueAccent, width: 2),
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
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        player.name,
                        style: const TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        player.email,
                        style: const TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          "LEVEL ${player.level} | ${FirebaseService().getRankTitle(player.level)}",
                          style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (player.xp % 1000) / 1000,
                          minHeight: 6,
                          backgroundColor: Colors.black.withValues(alpha: 0.05),
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${1000 - (player.xp % 1000)} XP UNTIL NEXT RANK",
                        style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // DYNAMIC GOAL MODULATION ANCHOR TILE
                _profileActionTile(
                  context,
                  title: "BIOMETRIC AUTO-TARGETS",
                  subtitle: "TARGETS: ${player.dailyStepTarget} STEPS | ${player.dailyExerciseTargetMinutes} MINS",
                  icon: Icons.monitor_heart_rounded,
                  color: Colors.teal,
                  onTap: () => _showBiometricsModal(context, player),
                ),

                const SizedBox(height: 12),

                // ACTIVITY SESSION QUICK ACCESS
                _profileActionTile(
                  context,
                  title: "ACTIVE SESSION",
                  subtitle: "START TACTICAL WORKOUT",
                  icon: Icons.fitness_center_rounded,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ActivityScreen(player: player)),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // ARMORY QUICK ACCESS
                _profileActionTile(
                  context,
                  title: "TACTICAL ARMORY",
                  subtitle: "EQUIPMENT & GEAR UPGRADES",
                  icon: Icons.shield_rounded,
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ArmoryScreen()),
                    );
                  },
                ),
                // Insert this inside the main operator profile card Column, right below the XP text breakdown:
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      "STAMINA: ${player.currentStamina} / ${player.maxStamina} AP",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: player.maxStamina > 0 ? (player.currentStamina / player.maxStamina) : 0,
                    minHeight: 8,
                    backgroundColor: Colors.black.withValues(alpha: 0.05),
                    color: Colors.amber,
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),

// RPG CHARACTER CLASS ATTRIBUTES MATRIX
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _attributeIndicator(label: "STR 💪", value: player.strength, color: Colors.redAccent),
                    _attributeIndicator(label: "AGI ⚡", value: player.agility, color: Colors.cyan),
                    _attributeIndicator(label: "END 🛡️", value: player.endurance, color: Colors.orange),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  "METRICS",
                  style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.1,
                  children: [
                    profileStat(
                      title: "Steps Taken",
                      value: "${player.dailySteps} / ${player.dailyStepTarget}",
                      icon: Icons.directions_walk_rounded,
                      color: Colors.blueAccent,
                    ),
                    profileStat(
                      title: "Claimed Land",
                      value: player.totalLand.toString(),
                      icon: Icons.grid_view_rounded,
                      color: Colors.green,
                    ),
                    profileStat(
                      title: "Trust Index",
                      value: "${player.trustScore}/100",
                      icon: Icons.verified_user_rounded,
                      color: Colors.purple,
                    ),
                    profileStat(
                      title: "Active Domain",
                      value: player.team,
                      icon: Icons.groups_rounded,
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                profileStat(
                  title: "Accumulated Experience Score",
                  value: "${player.xp} XP",
                  icon: Icons.flash_on_rounded,
                  color: Colors.orange,
                  isFullWidth: true,
                ),
                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "UNLOCKED ACHIEVEMENTS",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 20),
                      achievementTile(
                        icon: Icons.emoji_events_rounded,
                        title: "Apex Walker",
                        subtitle: "${player.totalSteps} total tracking units logged",
                        isUnlocked: player.totalSteps >= 1000,
                      ),
                      const Divider(color: Colors.black12, height: 24),
                      achievementTile(
                        icon: Icons.public_rounded,
                        title: "Realm Conqueror",
                        subtitle: "${player.totalLand} hex lands secured instantly",
                        isUnlocked: player.totalLand >= 10,
                      ),
                      const Divider(color: Colors.black12, height: 24),
                      achievementTile(
                        icon: Icons.gavel_rounded,
                        title: "Honored Scout",
                        subtitle: "Maintained structural integrity level",
                        isUnlocked: player.trustScore >= 90,
                      ),
                      const Divider(color: Colors.black12, height: 24),
                      achievementTile(
                        icon: Icons.bolt_rounded,
                        title: "Grid Veteran",
                        subtitle: "Reached 5,000 baseline network points",
                        isUnlocked: player.xp >= 5000,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.5),
                      ),
                    ),
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
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text(
                      "TERMINATE SESSION",
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
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

  Widget _attributeIndicator({required String label, required int value, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
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

  Widget profileStat({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: isFullWidth ? MainAxisAlignment.start : MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: isFullWidth ? 18 : 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget achievementTile({
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
}

// Private biometric operational control overlay
class _BiometricsEditorSheet extends StatefulWidget {
  final PlayerModel player;
  const _BiometricsEditorSheet({required this.player});

  @override
  State<_BiometricsEditorSheet> createState() => _BiometricsEditorSheetState();
}

class _BiometricsEditorSheetState extends State<_BiometricsEditorSheet> {
  late double _height;
  late double _weight;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _height = widget.player.heightCm ?? 170.0;
    _weight = widget.player.weightKg ?? 65.0;
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
              const Text("CALIBRATE BIOMETRICS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87, letterSpacing: 0.5)),
              if (_isSaving) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
            ],
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
                    stepTarget: matrix['steps'],
                    exerciseTarget: matrix['mins'],
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  setState(() => _isSaving = false);
                }
              },
              child: const Text("SAVE TARGET MATRIX", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          )
        ],
      ),
    );
  }
}