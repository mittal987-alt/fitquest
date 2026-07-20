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

  void _showUpdateAvatarDialog(BuildContext context, PlayerModel player) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameController = TextEditingController(text: player.name);
    final ImagePicker picker = ImagePicker();
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            title: Text(
              "EDIT OPERATOR PROFILE",
              style: theme.textTheme.titleLarge?.copyWith(
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
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: colorScheme.primary),
                            const SizedBox(height: 16),
                            Text(
                              "SYNCING CHANGES...",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      "CODENAME",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "Enter codename",
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "AVATAR UPLOAD",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.05),
                              foregroundColor: colorScheme.onSurface,
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
                                      SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: colorScheme.error),
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
                              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.05),
                              foregroundColor: colorScheme.onSurface,
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
                                      SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: colorScheme.error),
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
                      child: Text("CANCEL", style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
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
                              SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: colorScheme.error),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(child: Text("NOT LOGGED IN", style: TextStyle(color: colorScheme.onSurface))),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: StreamBuilder<PlayerModel?>(
        stream: FirebaseService().getPlayerStream(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: CircularProgressIndicator(color: colorScheme.primary));
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
                      _buildSectionTitle(context, "TELEMETRY LOGS (LAST 7 DAYS)"),
                      const SizedBox(height: 16),
                      _buildActivityChart(context, player),
                      const SizedBox(height: 32),
                      _buildSectionTitle(context, "OPERATOR ACHIEVEMENTS"),
                      const SizedBox(height: 16),
                      _buildAchievementGallery(context, player),
                      const SizedBox(height: 32),
                      _buildSectionTitle(context, "SYSTEM SETTINGS"),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SliverAppBar(
      expandedHeight: 340,
      backgroundColor: colorScheme.surface,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.5),
                    colorScheme.surface,
                  ],
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
                          backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                          backgroundImage: player.avatar.isNotEmpty ? NetworkImage(player.avatar) : null,
                          child: player.avatar.isEmpty ? Icon(Icons.person, size: 60, color: colorScheme.primary) : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showUpdateAvatarDialog(context, player),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                              child: Icon(Icons.edit, color: colorScheme.onPrimary, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      player.name.toUpperCase(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      "LVL ${player.level} ${FirebaseService().getRankTitle(player.level)}",
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    if (player.fitnessGoal != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          player.fitnessGoal!.replaceAll('_', ' ').toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildStatRow(context, player),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, PlayerModel player) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statItem(context, "${player.totalSteps}", "STEPS", icon: Icons.directions_walk_rounded, color: Colors.greenAccent),
        _statDivider(context),
        _statItem(context, "${player.xp}", "XP", icon: Icons.bolt_rounded, color: Colors.amberAccent),
        _statDivider(context),
        _statItem(context, "${player.currency}", "CREDITS", icon: Icons.monetization_on_rounded, color: Colors.cyanAccent),
      ],
    );
  }

  Widget _statItem(BuildContext context, String value, String label, {IconData? icon, Color? color}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        if (icon != null) Icon(icon, color: color ?? colorScheme.onSurfaceVariant, size: 16),
        if (icon != null) const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _statDivider(BuildContext context) {
    return Container(
      height: 30,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildActivityChart(BuildContext context, PlayerModel player) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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

      final bool isGoalMet = value >= player.dailyStepTarget;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: isGoalMet ? Colors.greenAccent : colorScheme.primary,
              width: 16,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: player.dailyStepTarget.toDouble(),
                color: colorScheme.onSurface.withValues(alpha: 0.05),
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
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: ((barGroups.isEmpty ? 12000 : barGroups.map((e) => e.barRods[0].toY).reduce((a, b) => a > b ? a : b) * 1.2)
              .clamp(player.dailyStepTarget * 1.2, double.infinity))
              .toDouble(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: colorScheme.surface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  "${rod.toY.toInt()} steps",
                  TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final date = now.subtract(Duration(days: 6 - value.toInt()));
                  final label = DateFormat('E').format(date).toUpperCase();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold)),
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

  Widget _buildAchievementGallery(BuildContext context, PlayerModel player) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: kGlobalAchievements.map((achievement) {
          final isUnlocked = player.unlockedAchievements.contains(achievement.id);
          final isLast = kGlobalAchievements.last.id == achievement.id;
          
          return Column(
            children: [
              _achievementRow(
                context,
                achievement.icon,
                achievement.title,
                achievement.description,
                isUnlocked,
                achievement.color,
              ),
              if (!isLast) Divider(height: 32, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _achievementRow(BuildContext context, IconData icon, String title, String subtitle, bool isUnlocked, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnlocked ? color.withValues(alpha: 0.1) : colorScheme.onSurface.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isUnlocked ? color : colorScheme.onSurfaceVariant.withValues(alpha: 0.2), size: 24),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isUnlocked ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isUnlocked ? colorScheme.onSurfaceVariant : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (isUnlocked)
          const Icon(Icons.verified_outlined, color: Colors.greenAccent, size: 20)
        else
          Icon(Icons.lock_outline_rounded, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2), size: 20),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context, PlayerModel player) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          _ghostStriderToggle(context, player),
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

  Widget _ghostStriderToggle(BuildContext context, PlayerModel player) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        SwitchListTile.adaptive(
          secondary: Icon(Icons.psychology_outlined, color: colorScheme.secondary, size: 22),
          title: Text(
            "GHOST STRIDER",
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          subtitle: Text(
            "ENABLE HISTORICAL TELEMETRY & LOOT",
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          value: player.isGhostStriderEnabled,
          activeThumbColor: colorScheme.secondary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          onChanged: (val) async {
            await FirebaseService().updateGhostStriderToggle(player.uid, val);
          },
        ),
        Divider(height: 1, indent: 64, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ],
    );
  }

  void _showColorPicker(BuildContext context, PlayerModel player) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
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
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "SELECT TERRITORY COLOR",
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
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
                      border: isSelected ? Border.all(color: colorScheme.onSurface, width: 3) : null,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: Icon(icon, color: colorScheme.onSurfaceVariant, size: 22),
          title: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: title == "DARK MODE"
              ? Switch.adaptive(
                  value: theme.brightness == Brightness.dark,
                  activeColor: colorScheme.primary,
                  onChanged: (val) {
                    MyApp.of(context)?.toggleDarkMode();
                  },
                )
              : title == "TERRITORY COLOR"
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: player.territoryColor != null ? Color(int.parse(player.territoryColor!.replaceFirst('#', '0xFF'))) : colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.outline),
                      ),
                    )
                  : Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
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
                  backgroundColor: colorScheme.surface,
                  title: Text("NOTIFICATIONS", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  content: Text("Manage notification settings in your device system settings for maximum tactical efficiency.",
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("UNDERSTOOD", style: TextStyle(color: colorScheme.primary)),
                    ),
                  ],
                ),
              );
            } else if (title == "PRIVACY") {
              showAboutDialog(
                context: context,
                applicationName: "FitQuest",
                applicationVersion: "1.0.0 Tactical Build",
                applicationIcon: Icon(Icons.security_outlined, color: colorScheme.primary),
                children: [
                  const Text("Your telemetry data is encrypted and used only for RPG progression and team coordination."),
                ],
              );
            } else if (title == "HELP & SUPPORT") {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: colorScheme.surface,
                  title: Text("COMMAND SUPPORT", style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  content: Text("Tactical support is currently offline. Please refer to the Field Manual (FAQ) in the future update.",
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("CLOSE", style: TextStyle(color: colorScheme.primary)),
                    ),
                  ],
                ),
              );
            }
          },
        ),
        if (!isLast) Divider(height: 1, indent: 64, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ],
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
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
          backgroundColor: colorScheme.error.withValues(alpha: 0.1),
          foregroundColor: colorScheme.error,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colorScheme.error, width: 2),
          ),
        ),
      ),
    );
  }
}
