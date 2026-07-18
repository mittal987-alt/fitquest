import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/player_model.dart';
import '../models/achievement_model.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'goal_adjustment_screen.dart';
import '../main.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color _kPrimaryPurple = Color(0xFF8E2DE2);
  static const Color _kSecondaryPurple = Color(0xFF4A00E0);
  static const Color _kBgColor = Color(0xFF0D1117);
  static const Color _kSurfaceColor = Color(0xFF161B22);

  void _showUpdateAvatarDialog(BuildContext context, PlayerModel player) {
    final nameController = TextEditingController(text: player.name);
    final ImagePicker picker = ImagePicker();
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _kSurfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Colors.white10),
            ),
            title: const Text(
              "EDIT OPERATOR PROFILE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUpdating) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: _kPrimaryPurple),
                            SizedBox(height: 16),
                            Text(
                              "SYNCING CHANGES...",
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      "CODENAME",
                      style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "Enter codename",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "AVATAR UPLOAD",
                      style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                              if (image != null) {
                                try {
                                  setDialogState(() => isUpdating = true);
                                  final bytes = await image.readAsBytes();
                                  final url = await FirebaseService().uploadAvatarFile(player.uid, bytes);
                                  await FirebaseService().updateAvatar(uid: player.uid, avatarUrl: url);
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  setDialogState(() => isUpdating = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.redAccent),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.photo_library_outlined, size: 20),
                            label: const Text("GALLERY", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                              if (image != null) {
                                try {
                                  setDialogState(() => isUpdating = true);
                                  final bytes = await image.readAsBytes();
                                  final url = await FirebaseService().uploadAvatarFile(player.uid, bytes);
                                  await FirebaseService().updateAvatar(uid: player.uid, avatarUrl: url);
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  setDialogState(() => isUpdating = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.redAccent),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.camera_alt_outlined, size: 20),
                            label: const Text("CAMERA", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: isUpdating
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CANCEL", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        try {
                          setDialogState(() => isUpdating = true);
                          if (nameController.text.isNotEmpty && nameController.text != player.name) {
                            await FirebaseService().updatePlayerName(uid: player.uid, name: nameController.text);
                          }
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          setDialogState(() => isUpdating = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      },
                      child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: _kBgColor,
        body: Center(child: Text("NOT LOGGED IN", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: _kBgColor,
      body: StreamBuilder<PlayerModel?>(
        stream: FirebaseService().getPlayerStream(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: CircularProgressIndicator(color: _kPrimaryPurple));
          }

          final player = snapshot.data!;
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, player),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("TELEMETRY LOGS (LAST 7 DAYS)"),
                      const SizedBox(height: 16),
                      _buildActivityChart(player),
                      const SizedBox(height: 32),
                      _buildSectionTitle("OPERATOR ACHIEVEMENTS"),
                      const SizedBox(height: 16),
                      _buildAchievementGallery(player),
                      const SizedBox(height: 32),
                      _buildSectionTitle("SYSTEM SETTINGS"),
                      const SizedBox(height: 16),
                      _buildSettingsSection(context, player),
                      const SizedBox(height: 32),
                      _buildSignOutButton(context),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, PlayerModel player) {
    return SliverAppBar(
      expandedHeight: 340,
      backgroundColor: _kBgColor,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kSecondaryPurple, _kBgColor],
                ),
              ),
            ),
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: _kPrimaryPurple.withValues(alpha: 0.2),
                          backgroundImage: player.avatar.isNotEmpty ? NetworkImage(player.avatar) : null,
                          child: player.avatar.isEmpty ? const Icon(Icons.person, size: 60, color: _kPrimaryPurple) : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showUpdateAvatarDialog(context, player),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: _kPrimaryPurple, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      player.name.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 2),
                    ),
                    Text(
                      "LVL ${player.level} ${FirebaseService().getRankTitle(player.level)}",
                      style: const TextStyle(color: _kPrimaryPurple, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 4),
                    ),
                    if (player.fitnessGoal != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          player.fitnessGoal!.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildStatRow(player),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(PlayerModel player) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statItem("${player.totalSteps}", "STEPS", icon: Icons.directions_walk_rounded, color: Colors.greenAccent),
        _statDivider(),
        _statItem("${player.xp}", "XP", icon: Icons.bolt_rounded, color: Colors.amberAccent),
        _statDivider(),
        _statItem("${player.currency}", "CREDITS", icon: Icons.monetization_on_rounded, color: Colors.cyanAccent),
      ],
    );
  }

  Widget _statItem(String value, String label, {IconData? icon, Color? color}) {
    return Column(
      children: [
        if (icon != null) Icon(icon, color: color ?? Colors.white70, size: 16),
        if (icon != null) const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.white10,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2),
    );
  }

  Widget _buildActivityChart(PlayerModel player) {
    final List<BarChartGroupData> barGroups = [];
    final now = DateTime.now();
    final List<String> last7Days = List.generate(7, (i) {
      return DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: 6 - i)));
    });

    for (int i = 0; i < 7; i++) {
      double value = 0;
      final dateKey = last7Days[i];
      if (player.dailyHistory.containsKey(dateKey)) {
        value = (player.dailyHistory[dateKey]['steps'] as num?)?.toDouble() ?? 0;
      }
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: _kPrimaryPurple,
              width: 16,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: player.dailyStepTarget.toDouble(),
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 12000,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final day = last7Days[value.toInt()].split('-').last;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(day, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }

  Widget _buildAchievementGallery(PlayerModel player) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: kGlobalAchievements.map((achievement) {
          final isUnlocked = player.unlockedAchievements.contains(achievement.id);
          final isLast = kGlobalAchievements.last.id == achievement.id;
          
          return Column(
            children: [
              _achievementRow(
                achievement.icon,
                achievement.title,
                achievement.description,
                isUnlocked,
                achievement.color,
              ),
              if (!isLast) const Divider(height: 32, color: Colors.white10),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _achievementRow(IconData icon, String title, String subtitle, bool isUnlocked, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnlocked ? color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isUnlocked ? color : Colors.white24, size: 24),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isUnlocked ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isUnlocked ? Colors.white54 : Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (isUnlocked)
          const Icon(Icons.verified_outlined, color: Colors.greenAccent, size: 20)
        else
          const Icon(Icons.lock_outline_rounded, color: Colors.white10, size: 20),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, PlayerModel player) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _ghostStriderToggle(player),
          _settingsTile(context, player, Icons.track_changes_rounded, "GOALS", "ADAPTIVE MISSION TARGETS"),
          _settingsTile(context, player, Icons.palette_outlined, "TERRITORY COLOR", "CUSTOMIZE YOUR MAP PRESENCE"),
          _settingsTile(context, player, Icons.notifications_none_rounded, "NOTIFICATIONS", "MANAGE ALERT PREFERENCES"),
          _settingsTile(context, player, Icons.dark_mode_outlined, "DARK MODE", "SYSTEM THEME SETTINGS"),
          _settingsTile(context, player, Icons.security_outlined, "PRIVACY", "DATA & SECURITY CONTROL"),
          _settingsTile(context, player, Icons.help_outline_rounded, "HELP & SUPPORT", "FAQ & CONTACT CENTER", isLast: true),
        ],
      ),
    );
  }

  Widget _ghostStriderToggle(PlayerModel player) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.psychology_outlined, color: Colors.cyanAccent, size: 22),
          title: const Text(
            "GHOST STRIDER",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
          ),
          subtitle: const Text(
            "ENABLE HISTORICAL TELEMETRY & LOOT",
            style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          value: player.isGhostStriderEnabled,
          activeColor: Colors.cyanAccent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          onChanged: (val) async {
            await FirebaseService().updateGhostStriderToggle(player.uid, val);
          },
        ),
        const Divider(height: 1, indent: 64, color: Colors.white10),
      ],
    );
  }

  void _showColorPicker(BuildContext context, PlayerModel player) {
    final List<Color> colors = [
      Colors.cyanAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.redAccent,
      Colors.blueAccent,
      Colors.pinkAccent,
      Colors.amberAccent,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SELECT TERRITORY COLOR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 16, crossAxisSpacing: 16),
              itemCount: colors.length,
              itemBuilder: (context, index) {
                final color = colors[index];
                final hex = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                final isSelected = player.territoryColor == hex;

                return GestureDetector(
                  onTap: () async {
                    await FirebaseService().updateTerritoryColor(player.uid, hex);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2)] : null,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile(BuildContext context, PlayerModel player, IconData icon, String title, String subtitle, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: Icon(icon, color: Colors.white38, size: 22),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          trailing: title == "DARK MODE"
              ? Switch.adaptive(
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (val) {
                    MyApp.of(context)?.toggleDarkMode();
                  },
                )
              : title == "TERRITORY COLOR"
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: player.territoryColor != null ? Color(int.parse(player.territoryColor!.replaceFirst('#', '0xFF'))) : Colors.cyanAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                    )
                  : const Icon(Icons.chevron_right_rounded, color: Colors.white10),
          onTap: () {
            if (title == "GOALS") {
              Navigator.push(context, MaterialPageRoute(builder: (context) => GoalAdjustmentScreen(player: player)));
            } else if (title == "TERRITORY COLOR") {
              _showColorPicker(context, player);
            } else if (title == "DARK MODE") {
              MyApp.of(context)?.toggleDarkMode();
            } else if (title == "NOTIFICATIONS") {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: _kSurfaceColor,
                  title: const Text("NOTIFICATIONS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: const Text("Manage notification settings in your device system settings for maximum tactical efficiency.",
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("UNDERSTOOD", style: TextStyle(color: Colors.cyanAccent)),
                    ),
                  ],
                ),
              );
            } else if (title == "PRIVACY") {
              showAboutDialog(
                context: context,
                applicationName: "FitQuest",
                applicationVersion: "1.0.0 Tactical Build",
                applicationIcon: const Icon(Icons.security_outlined, color: Colors.cyanAccent),
                children: [
                  const Text("Your telemetry data is encrypted and used only for RPG progression and team coordination."),
                ],
              );
            } else if (title == "HELP & SUPPORT") {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: _kSurfaceColor,
                  title: const Text("COMMAND SUPPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: const Text("Tactical support is currently offline. Please refer to the Field Manual (FAQ) in the future update.",
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CLOSE", style: TextStyle(color: Colors.cyanAccent)),
                    ),
                  ],
                ),
              );
            }
          },
        ),
        if (!isLast) const Divider(height: 1, indent: 64, color: Colors.white10),
      ],
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final authService = AuthService();
          await authService.logout();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        },
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text(
          "TERMINATE SESSION",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
          foregroundColor: Colors.redAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.redAccent, width: 2),
          ),
        ),
      ),
    );
  }
}
