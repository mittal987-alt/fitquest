import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gear_model.dart';
import '../models/player_model.dart';
import '../services/firebase_service.dart';

class ArmoryScreen extends StatelessWidget {
  const ArmoryScreen({super.key});

  static const Color _bgColor = Color(0xFF0D1117);
  static const Color _cardColor = Color(0xFF161B22);
  static const Color _accentColor = Color(0xFF8E2DE2);

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final uid = firebaseService.auth.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(
          child: Text(
            "NOT LOGGED IN",
            style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "OPERATOR ARMORY",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<PlayerModel?>(
        stream: firebaseService.getPlayerStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _accentColor));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("FAILED TO LOAD DATA", style: TextStyle(color: Colors.redAccent)));
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
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
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
                          const Text(
                            "ACCUMULATED XP",
                            style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${player.xp} XP",
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_rounded, color: _accentColor, size: 32),
                      ),
                    ],
                  ),
                ),

                const TabBar(
                  tabs: [
                    Tab(text: "EQUIPMENT"),
                    Tab(text: "PURCHASE"),
                  ],
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  indicatorColor: _accentColor,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white10),
            SizedBox(height: 16),
            Text(
              "NO GEAR OWNED",
              style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, letterSpacing: 1),
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
              await service.equipGear(player.uid, gear);
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
              await service.purchaseGear(player.uid, gear);
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
    const cardColor = Color(0xFF161B22);
    const accentColor = Color(0xFF8E2DE2);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isEquipped ? accentColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
          width: isEquipped ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isEquipped ? accentColor : Colors.white10).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (isEquipped ? accentColor : Colors.white10).withValues(alpha: 0.2)),
            ),
            child: Icon(
              _getIcon(gear.icon),
              color: isEquipped ? accentColor : Colors.white38,
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
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  gear.description,
                  style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                ),
                if (!isOwned) ...[
                  const SizedBox(height: 8),
                  Text(
                    "${gear.price} XP",
                    style: TextStyle(
                      color: canAfford ? accentColor : Colors.redAccent,
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
              backgroundColor: isEquipped ? Colors.greenAccent.withValues(alpha: 0.2) : (isOwned ? accentColor.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05)),
              foregroundColor: isEquipped ? Colors.greenAccent : (isOwned ? accentColor : Colors.white),
              elevation: 0,
              side: BorderSide(
                color: isEquipped ? Colors.greenAccent.withValues(alpha: 0.3) : (isOwned ? accentColor.withValues(alpha: 0.3) : Colors.white10),
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
