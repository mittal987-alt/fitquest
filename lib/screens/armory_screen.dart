import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gear_model.dart';
import '../models/player_model.dart';
import '../services/firebase_service.dart';

class ArmoryScreen extends StatelessWidget {
  const ArmoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final uid = firebaseService.auth.currentUser?.uid;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (uid == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Text(
            "NOT LOGGED IN",
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.38), fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "OPERATOR ARMORY",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 18,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: StreamBuilder<PlayerModel?>(
        stream: firebaseService.getPlayerStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: colorScheme.primary));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text("FAILED TO LOAD DATA", style: TextStyle(color: colorScheme.error)));
          }

          final player = snapshot.data!;

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // XP BALANCE
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.4 : 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ACCUMULATED XP",
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${player.xp} XP",
                            style: TextStyle(color: colorScheme.onSurface, fontSize: 28, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shield_rounded, color: colorScheme.primary, size: 32),
                      ),
                    ],
                  ),
                ),

                TabBar(
                  tabs: const [
                    Tab(text: "EQUIPMENT"),
                    Tab(text: "PURCHASE"),
                  ],
                  labelColor: colorScheme.onSurface,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  indicatorColor: colorScheme.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      _buildEquipmentTab(context, player, firebaseService),
                      _buildPurchaseTab(context, player, firebaseService),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEquipmentTab(BuildContext context, PlayerModel player, FirebaseService service) {
    if (player.ownedGear.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              "NO GEAR OWNED",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ],
        ),
      );
    }

    final ownedItems = allGear.where((g) => player.ownedGear.contains(g.id)).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: ownedItems.length,
      itemBuilder: (context, index) {
        final gear = ownedItems[index];
        final slotKey = gear.slot.toString().split('.').last;
        final isEquipped = player.equippedGear[slotKey] == gear.id;

        return _GearListItem(
          gear: gear,
          isOwned: true,
          isEquipped: isEquipped,
          onAction: () async {
            if (!isEquipped) {
              try {
                await service.equipGear(player.uid, gear);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("EQUIPPED: ${gear.name.toUpperCase()}"),
                    backgroundColor: colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("EQUIP FAILED: $e"),
                    backgroundColor: colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  Widget _buildPurchaseTab(BuildContext context, PlayerModel player, FirebaseService service) {
    final availableItems = allGear.where((g) => !player.ownedGear.contains(g.id)).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: availableItems.length,
      itemBuilder: (context, index) {
        final gear = availableItems[index];
        final canAfford = player.xp >= gear.price;

        return _GearListItem(
          gear: gear,
          isOwned: false,
          isEquipped: false,
          canAfford: canAfford,
          onAction: () async {
            if (canAfford) {
              try {
                await service.purchaseGear(player.uid, gear);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("PURCHASED: ${gear.name.toUpperCase()}"),
                    backgroundColor: colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("PURCHASE FAILED: $e"),
                    backgroundColor: colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}

class _GearListItem extends StatelessWidget {
  final GearModel gear;
  final bool isOwned;
  final bool isEquipped;
  final bool canAfford;
  final VoidCallback onAction;

  const _GearListItem({
    required this.gear,
    required this.isOwned,
    required this.isEquipped,
    this.canAfford = true,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isEquipped ? colorScheme.primary.withValues(alpha: 0.5) : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isEquipped ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isEquipped ? colorScheme.primary : colorScheme.onSurface).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (isEquipped ? colorScheme.primary : colorScheme.onSurface).withValues(alpha: 0.2)),
            ),
            child: Icon(
              _getIcon(gear.icon),
              color: isEquipped ? colorScheme.primary : colorScheme.onSurfaceVariant,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gear.name.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colorScheme.onSurface, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  gear.description,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4),
                ),
                if (!isOwned) ...[
                  const SizedBox(height: 8),
                  Text(
                    "${gear.price} XP",
                    style: TextStyle(
                      color: canAfford ? colorScheme.primary : colorScheme.error,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: (isOwned && isEquipped) ? null : onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: isEquipped ? colorScheme.primary.withValues(alpha: 0.2) : (isOwned ? colorScheme.primary.withValues(alpha: 0.1) : colorScheme.onSurface.withValues(alpha: 0.05)),
              foregroundColor: isEquipped ? colorScheme.primary : (isOwned ? colorScheme.primary : colorScheme.onSurface),
              elevation: 0,
              side: BorderSide(
                color: isEquipped ? colorScheme.primary.withValues(alpha: 0.3) : (isOwned ? colorScheme.primary.withValues(alpha: 0.3) : colorScheme.onSurface.withValues(alpha: 0.1)),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              isEquipped ? "READY" : (isOwned ? "EQUIP" : "BUY"),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'boot_icon': return Icons.directions_walk_rounded;
      case 'shoe_icon': return Icons.run_circle_rounded;
      case 'goggles_icon': return Icons.visibility_rounded;
      case 'radio_icon': return Icons.settings_input_antenna_rounded;
      case 'vest_icon': return Icons.accessibility_new_rounded;
      case 'sleeve_icon': return Icons.sports_handball_rounded;
      case 'mask_icon': return Icons.air_rounded;
      default: return Icons.construction_rounded;
    }
  }
}
