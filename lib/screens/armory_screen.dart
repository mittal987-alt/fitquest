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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "EQUIPMENT ROOM",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<PlayerModel?>(
        stream: firebaseService.getPlayerStream(firebaseService.auth.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("FAILED TO LOAD PLAYER DATA"));
          }

          final player = snapshot.data!;

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // XP BALANCE
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 16,
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
                            "XP BALANCE",
                            style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${player.xp} XP",
                            style: const TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const Icon(Icons.shield_rounded, color: Colors.blueAccent, size: 32),
                    ],
                  ),
                ),

                const TabBar(
                  tabs: [
                    Tab(text: "EQUIPMENT"),
                    Tab(text: "PURCHASE"),
                  ],
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.black38,
                  indicatorColor: Colors.blueAccent,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
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
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.black12),
            SizedBox(height: 16),
            Text(
              "NO GEAR OWNED",
              style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
      );
    }

    final ownedItems = allGear.where((g) => player.ownedGear.contains(g.id)).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
      padding: const EdgeInsets.all(16),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEquipped ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
          width: isEquipped ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isEquipped ? Colors.blueAccent : Colors.grey).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getIcon(gear.icon),
              color: isEquipped ? Colors.blueAccent : Colors.black45,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gear.name.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                ),
                Text(
                  gear.description,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                if (!isOwned) ...[
                  const SizedBox(height: 4),
                  Text(
                    "${gear.price} XP",
                    style: TextStyle(
                      color: canAfford ? Colors.blueAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: (isOwned && isEquipped) ? null : onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: isEquipped ? Colors.green : (isOwned ? Colors.blueAccent : Colors.black87),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              isEquipped ? "EQUIPPED" : (isOwned ? "EQUIP" : "BUY"),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
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
      default: return Icons. construction_rounded;
    }
  }
}
